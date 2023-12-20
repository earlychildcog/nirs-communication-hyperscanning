
% just run the script. No input. Does everything in the background automatically.
clear oxyclass
pause(0.5)
pwd
addpath("C:\Users\NIRS_PC\Documents\MATLAB\nirs-sync");
pause(0.5)
%% start communication with oxysoft

oxy = oxyclass(1, "adult");
