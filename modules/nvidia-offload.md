# Optional NVIDIA offload module

The default build does not enable the LOQ's NVIDIA path because your priority stack values stability, sleep reliability, and lower maintenance over hybrid complexity.

If you need CUDA, gaming, or external-display offload later:

1. Install the packages in `packages/optional-nvidia.txt` and, if needed, `packages/optional-nvidia-aur.txt`.
2. Add the NVIDIA resume units and modeset parameters.
3. Test suspend, external monitor hotplug, and Hyprland resume before making it your daily path.
