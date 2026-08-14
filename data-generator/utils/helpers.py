import pandas as pd
import os

def save_csv(df: pd.DataFrame, name: str, csv_dir: str):
    os.makedirs(csv_dir, exist_ok=True)
    path = os.path.join(csv_dir, f"{name}.csv")
    df.to_csv(path, index=False)
    print(f"  wrote {len(df):,} rows -> {path}")
    return path