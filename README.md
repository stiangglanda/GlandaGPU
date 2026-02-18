# GlandaGPU v0.1

This Simple GPU is a memory-mapped 2D acceleration core. It handles VGA signal generation and provides hardware acceleration for basic geometric primitives.

## Hardware Parameters
| Parameter | Value | Description |
| :--- | :--- | :--- |
| **Resolution** | 640 x 480 | Industry standard VGA |
| **Refresh Rate**| 60 Hz | 25.175 MHz Pixel Clock |
| **Color Depth** | 12-bit (4-4-4) | Stored as 16-bit words (0x0RGB) |

## Architecture
The GPU currently consists of a **VGA Controller** that generates HSYNC/VSYNC signals and displays a test pattern.

## The First Generated Frame of the GPU
<img width="640" height="480" alt="vga_output" src="https://github.com/user-attachments/assets/7aa8341c-4a18-4a21-8b9a-545c005ddf8e" />

## Register Map (First draft)

| Offset | Name | R/W | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | `GPU_STATUS` | R | Bit 0: Busy (1=Drawing, 0=Idle). Bit 1: VSync Active. |
| `0x04` | `GPU_CONTROL`| W | Bit 0: Reset, Bit 1: Enable Video Output. |
| `0x08` | `CMD_TYPE` | W | 0=Clear, 1=Draw Rect, 2=Draw Line. |
| `0x0C` | `COLOR_FG` | W | Foreground Color |
| `0x10` | `COORD_X0` | W | Starting X coordinate. |
| `0x14` | `COORD_Y0` | W | Starting Y coordinate. |
| `0x18` | `COORD_X1` | W | Ending X coordinate / Width. |
| `0x1C` | `COORD_Y1` | W | Ending Y coordinate / Height. |
| `0x20` | `TRIGGER` | W | Writing any value here starts the Command Engine. |

## Commands(First draft)

### Solid Fill (Clear Screen)
- **Input:** `COLOR_FG`
- **Action:** Writes the color to every address in VRAM.

### Draw Rectangle
- **Input:** 
    - `COORD_X0`, `COORD_Y0` (Top Left)
    - `COORD_X1` (Width), 
    - `COORD_Y1` (Height), 
    - `COLOR_FG`.
- **Action:** Iterates X and Y counters to fill a region of memory.

### Draw Line
- **Input:** 
    - `COORD_X0`, `COORD_Y0` (Start)
    - `COORD_X1`, `COORD_Y1` (End), 
    - `COLOR_FG`.
- **Action:** Implements Bresenham’s Line Algorithm in hardware state machine.

## Interrupts
- `IRQ_VSYNC`: Fires at the start of vertical blanking
- `IRQ_IDLE`: Fires when the Command Engine finishes drawing
