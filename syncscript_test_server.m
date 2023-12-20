
% just run the script. No input. Does everything in the background automatically.
clear oxyclass
pause(0.5)
pwd
addpath("C:\Users\NIRS\Documents\MATLAB\nirs-sync");   % should use mfilename('fullpath') instead?
pause(0.5)
%% start communication with oxysoft

oxy = oxyclass(0, "baby-duo");
oxy.status_oxysoft_communication = -2;
oxy.init;
