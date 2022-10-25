import pyqtgraph as pg
import numpy as np

def pdm(x):
    
    n = len(x)
    y = np.zeros(n)
    out = np.zeros(n)
    error = np.zeros(n+1)  

    for i in range(n):
        y[i] = 2**14 if x[i] >= error[i] else 0
        out[i] = 1 if x[i] >= error[i] else 0
        error[i+1] = y[i] - x[i] + error[i]

    return y, error[0:n]

F_SAMPLING = 48000
OVERSAMPLING = 128
F_OVERSAMPLING = F_SAMPLING * OVERSAMPLING
NR_OF_SAMPLES = 128
FREQUENCY = 1000

AMPLITUDE = 1
OFFSET = 0

x_time = np.linspace(0, NR_OF_SAMPLES * OVERSAMPLING - 1, NR_OF_SAMPLES * OVERSAMPLING) / (F_SAMPLING * OVERSAMPLING)
# pcm_signal = OFFSET + AMPLITUDE * np.sin(2 * np.pi * FREQUENCY * x_time[::OVERSAMPLING])
pcm_signal = OFFSET + AMPLITUDE * np.sinc(2 * np.pi * FREQUENCY * (x_time[::OVERSAMPLING] - NR_OF_SAMPLES/2/F_SAMPLING))

upsampled_pcm = np.zeros(OVERSAMPLING * len(pcm_signal))
upsampled_pcm[::OVERSAMPLING] = pcm_signal

pcm_signal_fft = 20 * np.log10(2 * np.abs(np.fft.fft(pcm_signal))[0:np.uint(NR_OF_SAMPLES/2)])
upsampled_pcm_fft = 20 * np.log10(2 * np.abs(np.fft.fft(upsampled_pcm))[0:np.uint(NR_OF_SAMPLES * OVERSAMPLING/2)])

# n = 100
# fclk = 250e6 # clock frequency (Hz)
# t = np.arange(n) / fclk
# f_sin = 5e6 # sine frequency (Hz)

# x = 2**13 + 0.4 * 2**14 * np.sin(2*np.pi*f_sin*t)
# y, error = pdm(x)

# Enable antialiasing for prettier plots
pg.setConfigOptions(antialias=True)
pg.setConfigOptions(background='w')

win = pg.GraphicsLayoutWidget(show=True, title="PDM Plots")
win.resize(1000,600)
win.setWindowTitle('PDM Plots')

p1 = win.addPlot(title="Sinc Signal")
p1.showGrid(x=True, y=True)
p1.plot(x_time[::OVERSAMPLING], pcm_signal, pen='r', stepMode="right", symbol='+')
p1.plot(x_time, upsampled_pcm, pen='b', stepMode="right", symbol='x')

win.nextRow()
p2 = win.addPlot(title="Frequency")
p2.showGrid(x=True, y=True)
p2.plot(pcm_signal_fft, pen='r')
# p2.plot(upsampled_pcm_fft, pen='b')

# p1.plot(x=1e9*t, y=y, color='r')

# win.nextRow()
# p2 = win.addPlot(title="Error Signal")
# p2.plot(x=1e9*t, y=error, stepMode="left")

pg.exec()