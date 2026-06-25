"""
Build_all_trajectories.py

Master driver: produces the trajectory figures for the paper.

Region grouping is FIXED at 7 (Mexico separated from Central America). For each
denominator (MPI, Pew, ACS) and each view type (per-capita, disparity level,
deviation from baseline), one PNG is produced. Total = 3 x 3 = 9 figures, plus
3 long-format CSVs (one per denominator).

Outputs (Figures/ddp/):
  per100k_trajectory_60day_7groups.png               (MPI)
  disparity_trajectory_60day_7groups.png
  disparity_trajectory_60day_7groups_deviation.png
  per100k_trajectory_60day_PEW_7groups.png           (Pew)
  disparity_trajectory_60day_PEW_7groups.png
  disparity_trajectory_60day_PEW_7groups_deviation.png
  per100k_trajectory_60day_ACS_7groups.png           (ACS)
  disparity_trajectory_60day_ACS_7groups.png
  disparity_trajectory_60day_ACS_7groups_deviation.png

CSVs (Data/):
  trajectory_60day_7groups_long.csv                  (MPI)
  trajectory_60day_PEW_7groups_long.csv              (Pew)
  trajectory_60day_ACS_7groups_long.csv              (ACS)

Sample: DDP arrests filtered to MPI-states (apples-to-apples across denoms).

Run:  python Build_all_trajectories.py
"""

from trajectory_helpers import (
    DENOMINATOR_LOADERS,
    load_filtered_ddp,
    build_trajectory,
    plot_per100k,
    plot_disparity,
    plot_deviation,
    figure_paths,
)


def run_one(denom_label, grouping, df):
    print(f"\n--- {denom_label} | grouping={grouping} ---")
    denominators = DENOMINATOR_LOADERS[denom_label](grouping=grouping)
    total = sum(denominators.values())
    for r, p in denominators.items():
        print(f"  {r:<32s}  {p:>14,.0f}  ({p/total*100:5.1f}%)")
    print(f"  {'TOTAL':<32s}  {total:>14,.0f}")

    ts = build_trajectory(df, denominators, grouping=grouping)

    p100k_path, disp_path, dev_path, csv_path = figure_paths(denom_label, grouping)
    ts.to_csv(csv_path, index=False)
    print(f"  -> CSV: {csv_path}")

    plot_per100k(ts, denom_label, grouping, p100k_path)
    print(f"  -> {p100k_path.name}")
    plot_disparity(ts, denom_label, grouping, disp_path)
    print(f"  -> {disp_path.name}")
    plot_deviation(ts, denom_label, grouping, dev_path)
    print(f"  -> {dev_path.name}")


def main():
    grouping = 7  # Mexico separated from Central America (fixed).
    print("Loading + filtering DDP (grouping=7)...")
    df = load_filtered_ddp(grouping=grouping)
    n_post = (df.win_idx >= 0).sum()
    n_pre  = (df.win_idx <  0).sum()
    print(f"\n=== {len(df):,} records ({n_pre:,} pre / {n_post:,} post) ===")
    for denom in ('MPI', 'Pew', 'ACS'):
        run_one(denom, grouping, df)

    print("\nDone. 9 figures + 3 CSVs.")


if __name__ == '__main__':
    main()
