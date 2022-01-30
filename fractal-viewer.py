## Idee
# Antud programm annab võimaluse uurida Mandelbroti hulga.
# Mis on Mandelbroti hulk? https://youtu.be/MwjsO6aniig

## Milline tehnoloogia on vajalik programmi käivitamiseks:
#   > 64-bitine Python 3x
#   > Tkinter
#   > Numpy
#   > Numba
#   > Pillow (PIL fork)
#   > Matplotlib

## Väike kasutamisjuhend
#   > liikumine - wasd või hjkl klahvid
#   > lähenemine - i (nagu "in")
#   > kaugenemine - o (nagu "out")
#   > värskendamine - r (nagu "refresh")
#   Parameetrid imax ja rmax reguleerivad kujude täpsust.
#   > suurem imax => parem pilt, kuid rohkem aega kulub selle genereerimiseks
#   Parameeter cmap (nagu "colormap") reguleerib pildi värvust.
#   > võimalikud väärtused - https://matplotlib.org/users/colormaps.html

import numpy as np
from numba import njit, prange, uint8, uint16, complex128, float64

import tkinter as tk
from PIL import Image, ImageTk
from matplotlib import cm

## Järgmised funksioonid on kompileeritud Numba teegiga

@njit(uint16(complex128, uint16, uint8), fastmath=True)
def f(z, imax, rmax):
    '''Funksioon, mille graafiku meie konstrueerime komplekstasandil, tagastab
    mittenegatiivse täisarvu vahemikus 0-imax'''
    c = z
    for i in range(imax):
        if abs(z) > rmax:
            return i
        ### Fraktali kuju võib muuta alloleva valemi kaudu.
        ## Mandelbrot fractal
        #z = z*z + c
        ## Burning ship fractal
        #z = np.square(np.complex(np.abs(np.real(z)), np.abs(np.imag(z)))) + c
        ## Tricorn fractal
        #z = np.square(np.conj(z)) + c
        ## Custom
        z = z*z*z*z + c
    return imax

@njit(float64[:,:](float64, float64, float64, float64, uint16, uint16, uint16, uint8), parallel=True)
def fractal_set(xmin, xmax, ymin, ymax, H, W, imax, rmax):
    '''Tagastab 2d numpy.array objekti, mille elemendid on 64-bitised
    ujukomaarvud vahemikus 0-1'''
    re = np.linspace(xmin, xmax, W) # reaalarvud
    im = np.linspace(ymin, ymax, H) # imaginaararvud
    se = np.empty(W*H)
    for a in prange(W):
        for b in prange(H):
            se[a*W+b] = f(complex(re[a],im[b]), imax, rmax)/imax
    return se.reshape((W,H)).T


def get_image(xmin, xmax, ymin, ymax, H, W, imax, rmax, cmap):
    '''Tagastab objekti, mida Tk võib kuvada'''
    return ImageTk.PhotoImage(Image.fromarray(cm.get_cmap(cmap)(fractal_set(xmin,
        xmax,ymin,ymax,H,W,imax,rmax), bytes=True)))

def main():
    '''Peafunktsioon'''
    H = 512; W = 512;
    xmin = -2.0; xmax = 0.5;
    ymin = -1.25; ymax = 1.25;
    imax = 256; rmax = 2;
    cmap = 'cubehelix'

    def unfocus(event):
        nonlocal root
        root.focus()     

    def handle_keys(event):
        nonlocal xmin, xmax, ymin, ymax, H, W, imax_var, rmax_var, cmap_var
        dx = xmax-xmin; dy = ymax-ymin
        pack = {'r': (0, 0, 0, 0),

                'i': (dx/4, -dx/4, dy/4, -dy/4),
                'o': (-dx/2, dx/2, -dy/2, dy/2),

                'h': (-dx/2, -dx/2, 0, 0),
                'j': (0, 0, dy/2, dy/2),
                'k': (0, 0, -dy/2, -dy/2),
                'l': (dx/2, dx/2, 0, 0),

                'w': (0, 0, -dy/2, -dy/2),
                'a': (-dx/2, -dx/2, 0, 0),
                's': (0, 0, dy/2, dy/2),
                'd': (dx/2, dx/2, 0, 0)}.get(event.keysym)

        if pack:
            dxmin, dxmax, dymin, dymax = pack
            xmin += dxmin; xmax += dxmax
            ymin += dymin; ymax += dymax
            new_image = get_image(xmin, xmax, ymin, ymax, H, W,
                                  np.uint16(imax_var.get()),
                                  np.uint8(rmax_var.get()), cmap_var.get())
            label.configure(image=new_image)
            label.image = new_image

    root = tk.Tk()
    root.title('projectBenoit')

    tk_image = get_image(xmin, xmax, ymin, ymax, H, W, imax, rmax, cmap)
    
    label = tk.Label(root, image=tk_image)
    label.pack()
    
    root.bind_class('Tk', '<Key>', handle_keys)

    ## TODO: a class on top of stringvar to avoid copypasta code

    tk.Label(root, text='imax').pack()
    imax_var = tk.StringVar()
    imax_var.set(imax)
    imax_entry = tk.Entry(root, textvariable=imax_var)
    imax_entry.bind('<Key-Return>', unfocus)
    imax_entry.pack()

    tk.Label(root, text='rmax').pack()
    rmax_var = tk.StringVar()
    rmax_var.set(rmax)
    rmax_entry = tk.Entry(root, textvariable=rmax_var)
    rmax_entry.bind('<Key-Return>', unfocus)
    rmax_entry.pack()

    tk.Label(root, text='cmap').pack()
    cmap_var = tk.StringVar()
    cmap_var.set(cmap)
    cmap_entry = tk.Entry(root, textvariable=cmap_var)
    cmap_entry.bind('<Key-Return>', unfocus)
    cmap_entry.pack()

    tk.mainloop()

if __name__ == "__main__":
    main()
