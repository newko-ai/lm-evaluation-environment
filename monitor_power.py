import time
import subprocess
import json
import sys
from datetime import datetime
import signal
import os
import re
from threading import Thread, Lock
from typing import Dict, List, Optional
import logging
from dataclasses import dataclass, asdict
from contextlib import contextmanager

@dataclass
class EvalProgress:
    examples_evaluated: int = 0
    tokens_generated: int = 0
    current_task: str = ""

@dataclass
class Measurement:
    timestamp: float
    power_draw: float
    memory_used: float
    gpu_utilization: float
    interval: float
    examples_evaluated: int
    tokens_generated: int
    current_task: str

class PowerMonitor:
    def __init__(self, output_file: str, eval_log_file: str):
        self.output_file = output_file
        self.eval_log_file = eval_log_file
        self.start_time = time.time()
        self.measurements: List[Measurement] = []
        self.running = True
        self.eval_progress = EvalProgress()
        self.lock = Lock()

        # Set up logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

        # Initialize signal handlers
        self._setup_signal_handlers()

    def _setup_signal_handlers(self) -> None:
        """Set up handlers for various signals"""
        signals = [signal.SIGTERM, signal.SIGINT]
        for sig in signals:
            signal.signal(sig, self.handle_signal)

    def handle_signal(self, signum: int, frame) -> None:
        """Handle termination signals gracefully"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        self.save_measurements()

    @contextmanager
    def measurement_lock(self):
        """Context manager for thread-safe operations"""
        self.lock.acquire()
        try:
            yield
        finally:
            self.lock.release()

    def parse_eval_line(self, line: str) -> None:
        """Parse a single line from the eval log file"""
        patterns = {
            'examples': (r'Evaluated (\d+)', 'examples_evaluated'),
            'tokens': (r'(\d+) tokens', 'tokens_generated'),
            'task': (r'Task: (.+)', 'current_task')
        }

        for key, (pattern, attr) in patterns.items():
            if key in line.lower():
                match = re.search(pattern, line)
                if match:
                    with self.measurement_lock():
                        if attr in ['examples_evaluated', 'tokens_generated']:
                            current_val = getattr(self.eval_progress, attr)
                            setattr(self.eval_progress, attr,
                                  current_val + int(match.group(1)))
                        else:
                            setattr(self.eval_progress, attr, match.group(1))

    def monitor_eval_output(self) -> None:
        """Monitor evaluation output file for progress updates"""
        if not os.path.exists(self.eval_log_file):
            self.logger.warning(f"Eval log file not found: {self.eval_log_file}")
            return

        try:
            with open(self.eval_log_file, 'r') as f:
                while self.running:
                    line = f.readline()
                    if not line:
                        time.sleep(0.1)
                        continue
                    self.parse_eval_line(line)
        except Exception as e:
            self.logger.error(f"Error monitoring eval output: {e}")

    def get_power_usage(self) -> tuple[float, float, float]:
        """Get current GPU power usage and metrics"""
        try:
            output = subprocess.check_output(
                ["nvidia-smi",
                 "--query-gpu=power.draw,memory.used,utilization.gpu",
                 "--format=csv,noheader,nounits"],
                timeout=5
            )
            return tuple(map(float, output.strip().decode().split(', ')))
        except subprocess.TimeoutExpired:
            self.logger.warning("nvidia-smi command timed out")
            return (0.0, 0.0, 0.0)
        except Exception as e:
            self.logger.error(f"Error getting power usage: {e}")
            return (0.0, 0.0, 0.0)

    def calculate_summary(self) -> Dict:
        """Calculate summary statistics from measurements"""
        if not self.measurements:
            return {
                'total_examples': 0,
                'total_tokens': 0,
                'avg_power': 0,
                'max_power': 0,
                'max_memory': 0,
                'avg_gpu_util': 0
            }

        power_values = [m.power_draw for m in self.measurements]
        memory_values = [m.memory_used for m in self.measurements]
        util_values = [m.gpu_utilization for m in self.measurements]

        return {
            'total_examples': self.eval_progress.examples_evaluated,
            'total_tokens': self.eval_progress.tokens_generated,
            'avg_power': sum(power_values) / len(power_values),
            'max_power': max(power_values),
            'max_memory': max(memory_values),
            'avg_gpu_util': sum(util_values) / len(util_values),
            'measurement_count': len(self.measurements),
            'total_duration_seconds': self.measurements[-1].timestamp
        }

    def save_measurements(self) -> None:
        """Save measurements and summary statistics to output file"""
        try:
            data = {
                'measurements': [asdict(m) for m in self.measurements],
                'total_duration': time.time() - self.start_time,
                'timestamp': datetime.now().isoformat(),
                'evaluation_progress': asdict(self.eval_progress),
                'summary': self.calculate_summary()
            }

            with open(self.output_file, 'w') as f:
                json.dump(data, f, indent=2)

            self.logger.info(f"Measurements saved to {self.output_file}")
        except Exception as e:
            self.logger.error(f"Error saving measurements: {e}")

    def monitor(self) -> None:
        """Main monitoring loop"""
        self.logger.info("Starting power monitoring...")

        # Start eval output monitoring in separate thread
        eval_thread = Thread(target=self.monitor_eval_output)
        eval_thread.daemon = True
        eval_thread.start()

        last_time = self.start_time

        try:
            while self.running:
                current_time = time.time()
                power, mem, util = self.get_power_usage()

                with self.measurement_lock():
                    measurement = Measurement(
                        timestamp=current_time - self.start_time,
                        power_draw=power,
                        memory_used=mem,
                        gpu_utilization=util,
                        interval=current_time - last_time,
                        examples_evaluated=self.eval_progress.examples_evaluated,
                        tokens_generated=self.eval_progress.tokens_generated,
                        current_task=self.eval_progress.current_task
                    )
                    self.measurements.append(measurement)

                last_time = current_time
                time.sleep(1)  # Sample every second

        except Exception as e:
            self.logger.error(f"Error in monitoring loop: {e}")
        finally:
            self.save_measurements()
            self.logger.info("Power monitoring stopped")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python monitor_power.py <output_file> <eval_log_file>")
        sys.exit(1)

    monitor = PowerMonitor(sys.argv[1], sys.argv[2])
    monitor.monitor()