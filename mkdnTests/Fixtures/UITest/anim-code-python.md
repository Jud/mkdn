# Python Code Animation

```python
from dataclasses import dataclass
from typing import List

@dataclass
class FrameCapture:
    fps: int = 30
    duration: float = 3.0
    output_dir: str = "/tmp/frames"

    def total_frames(self) -> int:
        return int(self.fps * self.duration)

    def frame_paths(self) -> List[str]:
        return [
            f"{self.output_dir}/frame_{i:04d}.png"
            for i in range(self.total_frames())
        ]
```

A paragraph below the code block for stagger contrast.
