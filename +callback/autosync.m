function autosync(~, ~, oxy)
disp('auto sync @now :)')
connected_devices = arrayfun(@(x)x.Connected == 1, oxy.tcp); % find all tcp servers with active connections
if any(connected_devices)
    try
        arrayfun(@(x)x.write('T','char'), oxy.tcp(connected_devices));   %% write event code as event marker
        oxy.write('T')
    catch
        warning("connection issues, connection disabled?")
    end
end