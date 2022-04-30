## Fractal Viewer

This was written back in 2018, as a high-school programming project. Thus, the comments are in Estonian.

### What do you need to run this program?
- 64-bit Python 3x
- Tkinter
- Numpy
- Numba
- Pillow (PIL fork)
- Matplotlib

### A small manual

Keys:

- Navigation - `wasd` or `hjkl` keys
- Zoom in and out - `i` and `o`
- Refresh - `r`

Parameters:

- `imax` - number of iterations, larger value leads to slower execution, but a better image.
- `rmax` - some threshold lmao, idk why it's an int
- `cmap` - colormap ([all available options](https://matplotlib.org/users/colormaps.html))
