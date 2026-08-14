from datetime import datetime, timedelta
import random

def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


DATA_START = datetime(2023, 1, 1)
DATA_END = datetime(2026, 8, 1)