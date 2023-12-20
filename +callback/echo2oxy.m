function echo2oxy(tcp, ~, oxy, other)
% echos the event sent through tcp to oxysoft
% reserved event names (capital):
%   - S for marking the start of the experiment
%   - R for restarting the dcom interface (though do not hope for much)
%   - Q for marking the end of the experiment
if tcp.NumBytesAvailable > 0
    iEvent = tcp.UserData.iEvent + 1;
    event = tcp.read(1,'char');
    if event == 'S'
        fprintf('Experiment starts:')
        % fprintf('stim pres computer connected, attempting sync handshake\n')
        subjNo = tcp.read(1,'double');
        time_other = tcp.read(1,'double');
        % timeStartNirsLaptop = seconds(datetime('now') - datetime('today'));
        % save(['data/sync_' num2str(subjNo) '_' char(datetime('now','Format','yyyyMMdd-HHmm')) '.mat'], "timeStartNirsLaptop"	,"timeStartPresentationComputer")
        fprintf(' subject %d. Waiting for event markers\n', subjNo)
        oxy.init_experiment(subjNo, time_other)
        event = [uint8(event) typecast([subjNo time_other], 'uint8')];  % for forwarding to other
    elseif event == 'R'
        fprintf('restarting dcom interface to oxysoft\n')
        oxy.dcom.delete(); % check if dcom interface is indeed working
        oxy.init_dcom();
        pause(0.1)
        oxy.write('R','reconnect')
    elseif event == 'Q'
        try
            oxy.dcom.WriteEvent('Q', 'quit')
            oxy.log_event('Q','quit')
            fprintf('Quit event marker sent, informing oxysoft\n')
        catch err
            warning('oxysoft connection not working or something')
            % warning(err.message)
        end
    else
        try
            oxy.write(event, sprintf('%event4d', iEvent))
            fprintf('event %c received and forwarded to oxysoft, count %d\n', event,  iEvent);
            tcp.UserData.iEvent = iEvent;
        catch err
            warning('oxysoft connection not working or something')
            fprintf(2,'%s\n', err.message)
        end
    end
    % forward the event to other
    if nargin > 3 && other.Connected
        other.write(event, 'uint8')
    end
end