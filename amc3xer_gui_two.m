function amc3xer_gui_two

    clc;

    % ---------------------------
    % App data
    % ---------------------------
    app = struct();
    app.libName   = 'NET_AMC3XER';
    app.header    = 'NET_AMC3XER.h';
    app.connected = false;
    app.stopFlag  = false;
    
    %异步流程运行状态
    app.seqTimer      = [];%定时器对象句柄-保存创建出来的timer
    app.seqRunning    = false;%当前序列是否正在运行   
    app.currentCycle  = 0;%当前循环次数
    app.totalCycles   = 0;%总循环次数
    app.currentStep   = 0;%当前第几步
    app.waitingAxis   = [];%等待哪个轴结束
    app.currentTag    = '';%当前标志
    app.stepStartTime = [];%
    app.stepTimeoutSec = 30;%

    % For throttled monitor logging
    app.lastMonitorLogTime = [];
    app.lastMonitorRunState = [];
    app.lastMonitorPos = [];

    % ---------------------------
    % UI
    % ---------------------------
    app.fig = uifigure( ...
        'Name', 'AMC3XER Motion Debug GUI', ...
        'Position', [100 100 1000 520], ...
        'CloseRequestFcn', @(~,~)onCloseFigure());

    % Connection
    uilabel(app.fig, 'Position', [20 480 80 22], 'Text', 'IP Address');
    app.edtIP = uieditfield(app.fig, 'text', ...
        'Position', [100 480 140 22], ...
        'Value', '192.168.1.30');

    app.btnConnect = uibutton(app.fig, 'push', ...
        'Position', [260 480 100 24], ...
        'Text', 'Connect', ...
        'ButtonPushedFcn', @(~,~)onConnect());

    app.btnDisconnect = uibutton(app.fig, 'push', ...
        'Position', [380 480 100 24], ...
        'Text', 'Disconnect', ...
        'ButtonPushedFcn', @(~,~)onDisconnect());

    % Motion parameters
    uilabel(app.fig, 'Position', [20 430 120 22], 'Text', 'OutMod');
    app.edtOutMod = uieditfield(app.fig, 'numeric', ...
        'Position', [140 430 100 22], ...
        'Value', 0);

    uilabel(app.fig, 'Position', [250 430 120 22], 'Text', 'Curve (0/1)');
    app.edtCurve = uieditfield(app.fig, 'numeric', ...
        'Position', [360 430 100 22], ...
        'Value', 1);

    uilabel(app.fig, 'Position', [470 430 120 22], 'Text', 'Cycles');
    app.edtCycles = uieditfield(app.fig, 'numeric', ...
        'Position', [560 430 100 22], ...
        'Value', 9);

    uilabel(app.fig, 'Position', [690 430 120 22], 'Text', 'StartDec');
    app.edtStartDec = uieditfield(app.fig, 'numeric', ...
        'Position', [800 430 100 22], ...
        'Value', 0);

    uilabel(app.fig, 'Position', [20 390 120 22], 'Text', 'Vo (PPS)');
    app.edtVo = uieditfield(app.fig, 'numeric', ...
        'Position', [140 390 100 22], ...
        'Value', 1000);

    uilabel(app.fig, 'Position', [250 390 120 22], 'Text', 'Vt (PPS)');
    app.edtVt = uieditfield(app.fig, 'numeric', ...
        'Position', [360 390 100 22], ...
        'Value', 20000);

    uilabel(app.fig, 'Position', [470 390 120 22], 'Text', 'SD_EN');
    app.edtSDEN = uieditfield(app.fig, 'numeric', ...
        'Position', [560 390 100 22], ...
        'Value', 0);

    uilabel(app.fig, 'Position', [690 390 120 22], 'Text', 'WaitSYNC');
    app.edtWaitSYNC = uieditfield(app.fig, 'numeric', ...
        'Position', [800 390 100 22], ...
        'Value', 0);

    uilabel(app.fig, 'Position', [20 350 120 22], 'Text', 'AccTime(ms)');
    app.edtAcc = uieditfield(app.fig, 'numeric', ...
        'Position', [140 350 100 22], ...
        'Value', 200);

    uilabel(app.fig, 'Position', [250 350 120 22], 'Text', 'DecTime(ms)');
    app.edtDec = uieditfield(app.fig, 'numeric', ...
        'Position', [360 350 100 22], ...
        'Value', 200);

    % Sequence lengths
    uilabel(app.fig, 'Position', [20 310 120 22], 'Text', 'Y+ Length');
    app.edtYPosLen = uieditfield(app.fig, 'numeric', ...
        'Position', [140 310 100 22], ...
        'Value', 30000);

    uilabel(app.fig, 'Position', [250 310 120 22], 'Text', 'X+ Length');
    app.edtXPosLen = uieditfield(app.fig, 'numeric', ...
        'Position', [360 310 100 22], ...
        'Value', 30000);

    uilabel(app.fig, 'Position', [470 310 120 22], 'Text', 'Y- Length');
    app.edtYNegLen = uieditfield(app.fig, 'numeric', ...
        'Position', [560 310 100 22], ...
        'Value', 30000);

    % Buttons
    app.btnInitAxes = uibutton(app.fig, 'push', ...
        'Position', [20 240 120 30], ...
        'Text', 'Init X/Y Axes', ...
        'ButtonPushedFcn', @(~,~)onInitAxes());

    app.btnStart = uibutton(app.fig, 'push', ...
        'Position', [160 240 140 30], ...
        'Text', 'Start Cycles', ...
        'ButtonPushedFcn', @(~,~)onStart());

    app.btnStop = uibutton(app.fig, 'push', ...
        'Position', [320 240 120 30], ...
        'Text', 'Stop All', ...
        'ButtonPushedFcn', @(~,~)onStopAll());

    app.btnRefresh = uibutton(app.fig, 'push', ...
        'Position', [460 240 120 30], ...
        'Text', 'Refresh Status', ...
        'ButtonPushedFcn', @(~,~)refreshStatus());

    % Status display
    app.txtStatus = uitextarea(app.fig, ...
        'Position', [20 20 720 200], ...
        'Editable', 'off', ...
        'Value', {'Ready.'});

    app.fig.UserData = app;
    updateUIState();

    function a = getApp()
        a = app.fig.UserData;
    end

    function setApp(a)
        app.fig.UserData = a;
    end

    function logMsg(msg)
        a = getApp();
        old = a.txtStatus.Value;
        if ischar(old)
            old = {old};
        end

        t = datestr(now, 'HH:MM:SS');
        newLog = [old; {[t '  ' msg]}];

        maxLines = 300;
        if numel(newLog) > maxLines
            newLog = newLog(end-maxLines+1:end);
        end

        a.txtStatus.Value = newLog;
        drawnow limitrate;
    end

    %UI界面设置
    function updateUIState()
        a = getApp();

        if a.connected
            a.btnConnect.Enable    = 'off';
            a.btnDisconnect.Enable = 'on';
            a.btnInitAxes.Enable   = 'on';
            a.btnStart.Enable      = 'on';
            a.btnStop.Enable       = 'on';
            a.btnRefresh.Enable    = 'on';
            a.edtIP.Editable       = 'off';
        else
            a.btnConnect.Enable    = 'on';
            a.btnDisconnect.Enable = 'off';
            a.btnInitAxes.Enable   = 'off';
            a.btnStart.Enable      = 'off';
            a.btnStop.Enable       = 'off';
            a.btnRefresh.Enable    = 'off';
            a.edtIP.Editable       = 'on';
        end
    end
    
    %运行时UI设置
    function setRunningUI(isRunning)
        a = getApp();

        if isRunning
            a.btnConnect.Enable    = 'off';
            a.btnDisconnect.Enable = 'off';
            a.btnInitAxes.Enable   = 'off';
            a.btnStart.Enable      = 'off';
            a.btnRefresh.Enable    = 'off';
            a.btnStop.Enable       = 'on';
        else
            setApp(a);
            updateUIState();
            return;
        end

        setApp(a);
        drawnow limitrate;
    end
    
    %确认是否连接
    function ensureConnected()
        a = getApp();
        if ~a.connected || ~libisloaded(a.libName)
            error('Device not connected. Please click Connect first.');
        end
    end
    
    %一个简单函数（因为文档很多函数返回值为0）
    function mustOK(ret, name)
        if ret ~= 0
            error('%s failed, ret=%d', name, ret);
        end
    end

    %连接板卡
    function onConnect()
        a = getApp();
        try
            if ~libisloaded(a.libName)
                loadlibrary(a.libName, a.header);
                logMsg('Library loaded.');
            end

            ret = calllib(a.libName, 'SOCKET_init');
            if ret ~= 0
                error('SOCKET_init failed, ret=%d', ret);
            end

            a.connected = true;
            setApp(a);
            updateUIState();

            logMsg('Socket initialized successfully.');
            refreshStatus();

        catch ME
            try
                if libisloaded(a.libName)
                    calllib(a.libName, 'SOCKET_delete');
                    unloadlibrary(a.libName);
                end
            catch
        end
    a.connected = false;
    setApp(a);
    updateUIState();
    logMsg(['Connect failed: ' ME.message]);
        end
    end
    
    %断开连接板卡
    function onDisconnect()
        a = getApp();

        if a.seqRunning
            logMsg('Sequence is running. Please stop it first.');
            return;
        end

        try
            if libisloaded(a.libName)
                calllib(a.libName, 'SOCKET_delete');
                unloadlibrary(a.libName);
                logMsg('Socket deleted and library unloaded.');
            end

            a.connected = false;
            setApp(a);
            updateUIState();

        catch ME
            logMsg(['Disconnect failed: ' ME.message]);
        end
    end

    %运动轴初始化
    function onInitAxes()
        a = getApp();
        ensureConnected();

        ip = a.edtIP.Value;

        try
            mustOK(calllib(a.libName, 'Set_Axs', ip, uint32(0), uint32(0), uint32(0), uint32(0), uint32(0)), 'Set_Axs X disable');
            mustOK(calllib(a.libName, 'Set_Axs', ip, uint32(0), uint32(1), uint32(0), uint32(0), uint32(0)), 'Set_Axs X enable');

            mustOK(calllib(a.libName, 'Set_Axs', ip, uint32(1), uint32(0), uint32(0), uint32(0), uint32(0)), 'Set_Axs Y disable');
            mustOK(calllib(a.libName, 'Set_Axs', ip, uint32(1), uint32(1), uint32(0), uint32(0), uint32(0)), 'Set_Axs Y enable');

            logMsg('X/Y axes initialized.');
            refreshStatus();

        catch ME
            logMsg(['Init axes failed: ' ME.message]);
        end
    end
    
    %运行状态的刷新——问ailogmsg内容代码怎么理解（？）
    function refreshStatus()
        a = getApp();
        if ~a.connected
            logMsg('Not connected.');
            return;
        end

        ip = a.edtIP.Value;

        try
            xState = readAxisState(ip, 0);
            yState = readAxisState(ip, 1);

            speedX = readSpeed(ip, 0);
            speedY = readSpeed(ip, 1);

            logMsg(sprintf('X: pos=%u run=%s(%d) io=%d speed=%u', ...
                xState.pos, xState.runState.text, xState.runState.raw, ...
                xState.ioState.raw, speedX));

            logMsg(sprintf('Y: pos=%u run=%s(%d) io=%d speed=%u', ...
                yState.pos, yState.runState.text, yState.runState.raw, ...
                yState.ioState.raw, speedY));

            logMsg(sprintf('CEMG(X/Y)=%s(%d)/%s(%d)', ...
                xState.cemg.text, xState.cemg.raw, ...
                yState.cemg.text, yState.cemg.raw));

        catch ME
            logMsg(['Refresh status failed: ' ME.message]);
        end
    end
    
    %主函数（异步状态机）
    function onStart()
        a = getApp();
        ensureConnected();

        if a.seqRunning
            logMsg('Sequence already running.');
            return;
        end

        try
            validateParams();   % 先校验参数

            a = getApp();
            if a.seqRunning
                logMsg('Sequence already running.');
                return;
            end

            onInitAxes();
            a = getApp();
            
            a.stopFlag = false;
            a.seqRunning = true;
            a.currentCycle = 1;
            a.totalCycles = max(1, round(a.edtCycles.Value));
            a.currentStep = 1;
            a.waitingAxis = [];
            a.currentTag = '';
            a.stepStartTime = [];
            a.lastMonitorLogTime = [];
            a.lastMonitorRunState = [];
            a.lastMonitorPos = [];
            
            if isempty(a.seqTimer) || ~isvalid(a.seqTimer)
                a.seqTimer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period', 0.05, ...
                    'BusyMode', 'drop', ...
                    'TimerFcn', @(~,~)runSequenceTick(), ...
                    'ErrorFcn', @(~,evt)onTimerError(evt));%timer定时器：每隔0.05s调用一次runSequenceTick函数
            end

            setApp(a);
            setRunningUI(true);
            start(a.seqTimer);

            logMsg(sprintf('Sequence started: %d cycles.', a.totalCycles));

        catch ME
            a = getApp();
            a.seqRunning = false;
            setApp(a);
            setRunningUI(false);
            logMsg(['Start failed: ' ME.message]);
        end
    end
    
    %停止运动函数
    function onStopAll()
        a = getApp();
        a.stopFlag = true;
        setApp(a);

        try
        safeStopAxes();
        logMsg('Stop command sent to X/Y/Z.');
        catch ME
            logMsg(['Stop failed: ' ME.message]);
        end
    end
    
    %停止序列执行流程并且把运行状态恢复到"未运行状态"/传msg是想知道哪个地方出错了
    function stopSequenceInternal(msg)
        a = getApp();
        
        % 双保险：任何停止路径都再补一次停轴
        try
            safeStopAxes();
        catch
        end

        if ~isempty(a.seqTimer) && isvalid(a.seqTimer)
            %比较字符串函数-strcmp是否相等
            %判断定时器是否正在运行如果是那就停止定时器
            if strcmp(a.seqTimer.Running, 'on')
                stop(a.seqTimer);
            end
        end
        
        %清理运行状态
        a.seqRunning = false;
        a.stopFlag = false;
        a.waitingAxis = [];
        a.currentTag = '';
        a.stepStartTime = [];
        a.lastMonitorLogTime = [];
        a.lastMonitorRunState = [];
        a.lastMonitorPos = [];
        setApp(a);

        setRunningUI(false);
        logMsg(msg);
    end

    function onTimerError(~)%~：意思是不需要这个参数然后又不会有警告
        stopSequenceInternal('Sequence error: timer callback failed.');
    end
    
    %生成运动步骤但是不执行，由后续函数负责执行（更容易更改路径规则）（底层运动逻辑）
    function steps = getSequenceSteps()
        a = getApp();
        steps = {
            struct('axis', 1, 'dir', 0, 'len', round(a.edtYPosLen.Value), 'tag', 'Y+')
            struct('axis', 0, 'dir', 0, 'len', round(a.edtXPosLen.Value), 'tag', 'X+')
            struct('axis', 1, 'dir', 1, 'len', round(a.edtYNegLen.Value), 'tag', 'Y-')
            struct('axis', 0, 'dir', 0, 'len', round(a.edtXPosLen.Value), 'tag', 'X+')
        };
    end
    
    %主执行函数（异步状态机核心）
    function runSequenceTick()
        try
            a = getApp();
            
            %确认是否正在运行
            if ~a.seqRunning
                return;
            end
            
            %如果请求停止就立即停止序列
            if a.stopFlag
                stopSequenceInternal('Sequence stopped by user.');
                return;
            end
            
            steps = getSequenceSteps();
    
            if a.currentCycle > a.totalCycles
                stopSequenceInternal('All cycles completed.');
                refreshStatus();
                return;
            end
    
            stepInfo = steps{a.currentStep};
    
            %判断当前是不是开始执行步骤的运动
            if isempty(a.waitingAxis)
                logMsg(sprintf('Cycle %d/%d started, step %d: %s', ...
                    a.currentCycle, a.totalCycles, a.currentStep, stepInfo.tag));
    
                startMove(stepInfo.axis, stepInfo.dir, stepInfo.len, stepInfo.tag);
    
                a = getApp();
                a.waitingAxis = stepInfo.axis;
                a.currentTag = stepInfo.tag;
                a.stepStartTime = tic;
                a.lastMonitorLogTime = tic;
                a.lastMonitorRunState = [];
                a.lastMonitorPos = [];
                setApp(a);
                return;
            end
    
            % Motion already started -> monitor（监控运动）
            state = readAxisState(a.edtIP.Value, a.waitingAxis);
    
            if ~state.cemg.isNormal
                error('CEMG invalid during %s. Check emergency-stop wiring.', a.currentTag);
            end
    
            % Timeout protection
            if ~isempty(a.stepStartTime) && toc(a.stepStartTime) > a.stepTimeoutSec
                error('%s timeout waiting for stop.', a.currentTag);
            end
    
            % Throttled monitor log
            needLog = false;
    
            if isempty(a.lastMonitorRunState) || state.runState.raw ~= a.lastMonitorRunState
                needLog = true;
            end
    
            if isempty(a.lastMonitorPos) || abs(double(state.pos) - double(a.lastMonitorPos)) > 1000
                needLog = true;
            end
    
            if isempty(a.lastMonitorLogTime) || toc(a.lastMonitorLogTime) > 0.5
                needLog = true;
            end
    
            if needLog
                logMsg(sprintf('%s monitoring: pos=%u, runState=%s(%d), ioState=%d, CEMG=%s(%d)', ...
                    a.currentTag, ...
                    state.pos, ...
                    state.runState.text, state.runState.raw, ...
                    state.ioState.raw, ...
                    state.cemg.text, state.cemg.raw));
    
                a = getApp();
                a.lastMonitorLogTime = tic;
                a.lastMonitorRunState = state.runState.raw;
                a.lastMonitorPos = state.pos;
                setApp(a);
            end
    
            % Stop detected -> go next step
            if state.runState.raw == 0
                logMsg([a.currentTag ' finished.']);
    
                a = getApp();
                a.waitingAxis = [];
                a.currentTag = '';
                a.stepStartTime = [];
                a.lastMonitorLogTime = [];
                a.lastMonitorRunState = [];
                a.lastMonitorPos = [];
                
                %核心运动逻辑
                if a.currentStep < numel(steps)
                    a.currentStep = a.currentStep + 1;
                else
                    logMsg(sprintf('Cycle %d/%d finished.', a.currentCycle, a.totalCycles));
                    a.currentStep = 1;
                    a.currentCycle = a.currentCycle + 1;
                end
    
                setApp(a);
            end
        catch ME
            stopSequenceInternal(['Sequence error: ' ME.message]);
        end  
            
    end

    % ===========================
    % Motion / read status  运动轴运动函数（调用定长运动函数）
    % ===========================
    function startMove(axisId, dirVal, lenVal, tag)
        a = getApp();

        ip       = a.edtIP.Value;
        curve    = round(a.edtCurve.Value);
        outmod   = round(a.edtOutMod.Value);
        vo       = round(a.edtVo.Value);
        vt       = round(a.edtVt.Value);
        startDec = round(a.edtStartDec.Value);
        acc      = round(a.edtAcc.Value);
        dec      = round(a.edtDec.Value);
        sden     = round(a.edtSDEN.Value);
        waitsync = round(a.edtWaitSYNC.Value);

        logMsg(sprintf('Command: %s, axis=%d, dir=%d, len=%d', tag, axisId, dirVal, lenVal));

        ret = calllib(a.libName, 'DeltMov', ...
            ip, ...
            uint32(axisId), ...
            uint32(curve), ...
            uint32(dirVal), ...
            uint8(outmod), ...
            uint32(vo), ...
            uint32(vt), ...
            uint32(lenVal), ...
            uint32(startDec), ...
            uint32(acc), ...
            uint32(dec), ...
            uint32(sden), ...
            uint32(waitsync));

        if ret == -1
            error('DeltMov communication failed on %s.', tag);
        elseif ret == -2
            logMsg(sprintf('Warning: %s caused triangular profile, but motion still output.', tag));
        else
            logMsg(sprintf('%s StartDec returned: %d', tag, ret));
        end
    end

    function state = readAxisState(ip, axisId)
        a = getApp();

        pPos      = libpointer('uint32Ptr', 0);
        pRunState = libpointer('uint8Ptr', 0);
        pIOState  = libpointer('uint8Ptr', 0);
        pCEMG     = libpointer('uint8Ptr', 0);

        ret = calllib(a.libName, 'Read_Position', ip, uint32(axisId), ...
            pPos, pRunState, pIOState, pCEMG);
        mustOK(ret, sprintf('Read_Position axis %d', axisId));

        posRaw      = uint32(pPos.Value);
        runStateRaw = uint8(pRunState.Value);
        ioStateRaw  = uint8(pIOState.Value);
        cemgRaw     = uint8(pCEMG.Value);

        pos = bitand(posRaw, uint32(hex2dec('FFFFFF')));

        runState = struct();
        runState.raw  = runStateRaw;
        runState.text = decodeRunState(runStateRaw);

        ioState = struct();
        ioState.raw = ioStateRaw;
        ioState.SD  = logical(bitget(ioStateRaw, 1));
        ioState.ORG = logical(bitget(ioStateRaw, 2));
        ioState.ELn = logical(bitget(ioStateRaw, 3));
        ioState.ELp = logical(bitget(ioStateRaw, 4));

        cemg = struct();
        cemg.raw = cemgRaw;
        cemg.isNormal    = (cemgRaw == 0);
        cemg.isEmergency = (cemgRaw ~= 0);

        if cemg.isNormal
            cemg.text = '正常';
        else
            cemg.text = '急停/未接好';
        end

        state = struct();
        state.axisId   = uint32(axisId);
        state.pos      = pos;
        state.posRaw   = posRaw;
        state.runState = runState;
        state.ioState  = ioState;
        state.cemg     = cemg;
    end

    function txt = decodeRunState(v)
        switch uint8(v)
            case 0
                txt = '停止';
            case 1
                txt = '预启动';
            case 2
                txt = '直线加速过程';
            case 3
                txt = '定长高速运行';
            case 4
                txt = '直线减速过程';
            case 5
                txt = '回原点运动过程';
            case 6
                txt = '低速连续运动过程';
            case 7
                txt = '高速连续运动过程';
            otherwise
                txt = sprintf('未知状态(%u)', uint8(v));
        end
    end
    
    %速度读取函数
    function speed = readSpeed(ip, axisId)
        a = getApp();
        pSpeed = libpointer('uint32Ptr', 0);
        ret = calllib(a.libName, 'Read_Speed', ip, uint32(axisId), pSpeed);
        mustOK(ret, sprintf('Read_Speed axis %d', axisId));
        speed = pSpeed.Value;
    end
    
    %调用停止函数来停止运动轴
    function safeStopAxes()
        a = getApp();
    
        if ~a.connected
            return;
        end
    
        if ~libisloaded(a.libName)
            return;
        end
    
        ip = a.edtIP.Value;
    
        try
            calllib(a.libName, 'AxsStop', ip, uint32(0));
        catch
        end
    
        try
            calllib(a.libName, 'AxsStop', ip, uint32(1));
        catch
        end
    
        try
            calllib(a.libName, 'AxsStop', ip, uint32(2));
        catch
        end
    end

    % ===========================
    % Close
    % ===========================
    function onCloseFigure()
        try
            a = getApp();
            
            %补一层安全停轴使得关闭界面时候更安全
            try
                safeStopAxes();
            catch
            end
            if ~isempty(a.seqTimer) && isvalid(a.seqTimer)
                if strcmp(a.seqTimer.Running, 'on')
                    stop(a.seqTimer);
                end
                delete(a.seqTimer);
            end

            if libisloaded(a.libName)
                try
                    calllib(a.libName, 'SOCKET_delete');
                catch
                end
                unloadlibrary(a.libName);
            end
        catch
        end

        delete(app.fig);
    end
    
    %参数校验，防止界面输入值异常
    function validateParams()
        a = getApp();
        
        assert(a.edtCycles.Value >= 1, 'Cycles must be >= 1');
        assert(a.edtVo.Value >= 0, 'Vo must be >= 0');
        assert(a.edtVt.Value > 0, 'Vt must be > 0');
        assert(a.edtVo.Value <= a.edtVt.Value, 'Vo must be <= Vt');
        assert(a.edtAcc.Value >= 0, 'AccTime must be >= 0');
        assert(a.edtDec.Value >= 0, 'DecTime must be >= 0');
        assert(a.edtYPosLen.Value > 0, 'Y+ Length must be > 0');
        assert(a.edtXPosLen.Value > 0, 'X+ Length must be > 0');
        assert(a.edtYNegLen.Value > 0, 'Y- Length must be > 0');
        assert(ismember(round(a.edtCurve.Value), [0 1]), 'Curve must be 0 or 1');
    end

	% 新加的一行注释


    % 四月二十二号 00:26
end
