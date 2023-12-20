classdef oxyclass < handle
    properties
        % settings and flags
        status uint8 = 0 % 0 not started, 1 initialising, 2 experiment/recording started
        name_project = ''
        name_subj string = "000"
        name_role string = "test"
        date_start
        status_oxysoft_communication double = -1   % for the communication with oxysoft: -2 dummy, -1 for not attempted, 0 for not (most possibly) not established, 1 for established, 2 for established but not matching project name
        % interfaces
        dcom
        tcp
        % tcp settings
        ip_self char = '0.0.0.0'
        ip_other char = ''
        port = [55000 56000]
        tcp_role string
        % autosyncing callback
        autosync
        % event log
        fid_log = 0
    end
    methods
        function oxy = oxyclass(status, type, name_project)
            arguments
                status uint8 = 0
                type string {mustBeMember(type, ["baby-single" "baby-duo" "adult"])} = "adult"
                name_project char = ''
            end
            oxy.name_project = name_project;
            if status
                oxy.init(type);
            end
        end
        function init(oxy, type)
            oxy.status = 1;
            oxy.init_dcom
            if type == "adult"
                oxy.ip_other = '192.168.0.210';
                oxy.init_tcp_client();
                oxy.tcp_role = "client";
                oxy.name_role = "adult";
            else
                oxy.init_tcp_server();
                oxy.tcp_role = "server";
                oxy.name_role = "baby";
            end
        end
        function init_dcom(oxy)
            % initialises communication with oxysoft usimg a dcom interface, so that we can send markers
            if oxy.status_oxysoft_communication ~= -2
                fprintf("connection to oxysoft dcom interface attempted...\n")
                try
                    oxy.dcom = actxserver("OxySoft.OxyApplication");
                    oxy.check_dcom_connection();
                catch err
                    warning('no oxysoft communication')
                    fprintf(2, err.message)
                    fprintf(2, '\nFIX THIS!!!!!!!!!!!!!!!!!!!!\n')
                    oxy.status_oxysoft_communication = 0;
                end
            end
        end
        function init_tcp_server(oxy)
            % start tcp server that acts as intermediate between oxysoft and the stimuli presentation computer
            % baby-desktop
            oxy.tcp = tcpserver(oxy.ip_self,oxy.port(1),Timeout=10^12);
            oxy.tcp(1).UserData = struct;
            oxy.tcp(1).UserData.iEvent = 0;
            oxy.tcp(1).UserData.type = 'baby-desktop';
            % baby-parent (whether or not needed)
            oxy.tcp(2) = tcpserver(oxy.ip_self,oxy.port(2),Timeout=10^12);
            oxy.tcp(2).UserData = struct;
            oxy.tcp(2).UserData.iEvent = 0;
            oxy.tcp(2).UserData.type = 'baby-parent';
            % setup cross-communication
            oxy.tcp(1).configureCallback("byte",2, @(src,event)callback.echo2oxy(src, event, oxy, oxy.tcp(2)))
            oxy.tcp(2).configureCallback("byte",2, @(src,event)callback.echo2oxy(src, event, oxy, oxy.tcp(1)))
            fprintf('server started, waiting for the other computer to connect\n')
            oxy.autosync = timer('ExecutionMode', 'fixedRate', 'Period', 20, 'TimerFcn', @(src, event)callback.autosync(src, event, oxy));
        end
        function init_tcp_client(oxy)
            % start tcp server that acts as intermediate between oxysoft and the stimuli presentation computer
            oxy.tcp = tcpclient(oxy.ip_other, oxy.port(1), Timeout=10^12);
            oxy.tcp.configureCallback("byte",1, @(src,event)callback.echo2oxy(src, event, oxy))
            oxy.tcp.UserData = struct;
            oxy.tcp.UserData.iEvent = 0;
            fprintf('client started\n')
            time_self = posixtime(datetime('now','TimeZone','local'));        
            oxy.tcp.write([uint8('S') typecast(0,'uint8') typecast(time_self,'uint8')], "uint8")

        end
        function init_experiment(oxy, subjNo, time_other)    
            if nargin < 2
                subjNo = 0;
                time_other = 0;
            end
            time_self = posixtime(datetime('now','TimeZone','local'));
            oxy.write('S','start')      % note: log has not initialised yet (so we write to log later)
            oxy.check_dcom_connection(1); % check if dcom interface is indeed working
            oxy.name_subj = num2str(subjNo);
            % start log file
            if oxy.fid_log == 0
                oxy.fid_log = fopen("sync_" + oxy.name_project + "_" + oxy.name_subj + "_" + oxy.name_role + "_" + string(datetime('now','Format','yyyyMMdd-HHmm')) + ".log", 'w');
                oxy.log('#project,%s\n',oxy.name_project)
                oxy.log('#subject,%s_%s\n', oxy.name_subj, oxy.name_role)
                oxy.log('#created,%s\n', string(datetime(time_self, 'ConvertFrom','posixtime','TimeZone','local')))
                oxy.log('#time_other,%f\n', string(datetime(time_other, 'ConvertFrom','posixtime','TimeZone','local')))
                oxy.log('#name,event,time,description\n#datatype,string,float,string')
                oxy.log('event,time,description')
            end
            oxy.log_event('S','start', time_self)
            % start auto sync also
            if ~isempty(oxy.autosync)
                oxy.autosync.start;
            end
            oxy.status = 2;
        end
        function check_dcom_connection(oxy, flag_retry)
            arguments
                oxy oxyclass
                flag_retry logical = false
            end
            if oxy.status_oxysoft_communication ~= -2
                if isempty(oxy.dcom.project)
                    warning("no connection to oxysoft detected")
                    oxy.status_oxysoft_communication = 0;
                else
                    if strcmp(oxy.dcom.project.strName, oxy.name_project)
                        fprintf("connection to oxysoft detected for project %s; all seem good\n", oxy.name_project)
                        oxy.status_oxysoft_communication = 1;
                    else
                        fprintf(2,"connection to oxysoft detected, but project name appears as %s instead of %s\n", oxy.dcom.project.strName, oxy.name_project)
                        fprintf(2, "It could all be fine, but double check that oxysoft receive markers, and you have loaded the right layout and settings in oxysoft\n")
                        oxy.status_oxysoft_communication = 2;
                    end
                end
                if ~oxy.status_oxysoft_communication == 0 && flag_retry
                    oxy.dcom.delete();
                    oxy.init_dcom();
                end
            end
        end
        function write(oxy, event, description, time_here)
            arguments
                oxy oxyclass
                event char
                description char = ''
                time_here double = posixtime(datetime('now','TimeZone','local'))
            end
            if oxy.status_oxysoft_communication >= 0
                oxy.dcom.WriteEvent(event,description)
            end
            oxy.log_event(event, description, time_here)
        end
        function delete(oxy)
            oxy.dcom.delete();
            oxy.tcp.delete();
        end
        function log(oxy, message, varargin)
            if oxy.fid_log ~= 0
                fprintf(oxy.fid_log, message, varargin{:});
            end
        end
        function log_event(oxy, event, description, time_self)
            arguments
                oxy oxyclass
                event char
                description char = ''
                time_self double = posixtime(datetime('now','TimeZone','local'))
            end
            oxy.log('%s,%f,%s', event, time_self, description)
        end
    end
end