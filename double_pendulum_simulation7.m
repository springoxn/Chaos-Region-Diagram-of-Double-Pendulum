function double_pendulum_simulation7()
    % 创建主界面
    fig = figure('Name', '双摆系统模拟 (音乐版)', 'NumberTitle', 'off', ...
                 'Position', [100, 100, 1000, 700], 'Color', [0.95 0.95 0.95]);
    
    % 创建双摆动画区域
    ax_pendulum = axes('Parent', fig, 'Position', [0.05 0.3 0.45 0.65]);
    axis(ax_pendulum, 'equal');
    xlim(ax_pendulum, [-2.5 2.5]);
    ylim(ax_pendulum, [-2.5 2.5]);
    title(ax_pendulum, '双摆运动模拟');
    grid(ax_pendulum, 'on');
    hold(ax_pendulum, 'on');
    
    % 创建相图区域
    ax_phase = axes('Parent', fig, 'Position', [0.55 0.3 0.4 0.3]);
    title(ax_phase, '相空间轨迹 (θ₁ vs θ₂)');
    xlabel(ax_phase, 'θ₁ (rad)');
    ylabel(ax_phase, 'θ₂ (rad)');
    grid(ax_phase, 'on');
    hold(ax_phase, 'on');
    
    % 创建Lyapunov指数区域
    ax_lyap = axes('Parent', fig, 'Position', [0.55 0.65 0.4 0.3]);
    title(ax_lyap, '最大Lyapunov指数');
    xlabel(ax_lyap, '时间 (s)');
    ylabel(ax_lyap, 'λ');
    grid(ax_lyap, 'on');
    hold(ax_lyap, 'on');
    
    % 控制面板
    uipanel('Parent', fig, 'Title', '控制面板', ...
            'Position', [0.05 0.05 0.9 0.2], 'BackgroundColor', [0.9 0.9 0.9]);
    
    % 初始角度滑块
    uicontrol('Parent', fig, 'Style', 'text', 'String', '初始角度 θ₁ (度):', ...
              'Position', [70, 80, 120, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    slider_theta1 = uicontrol('Parent', fig, 'Style', 'slider', ...
                             'Min', -180, 'Max', 180, 'Value', 90, ...
                             'Position', [200, 80, 200, 20], ...
                             'Callback', @update_parameters);
    
    uicontrol('Parent', fig, 'Style', 'text', 'String', '初始角度 θ₂ (度):', ...
              'Position', [70, 50, 120, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    slider_theta2 = uicontrol('Parent', fig, 'Style', 'slider', ...
                             'Min', -180, 'Max', 180, 'Value', 0, ...
                             'Position', [200, 50, 200, 20], ...
                             'Callback', @update_parameters);
    
    % 显示当前角度值
    text_theta1 = uicontrol('Parent', fig, 'Style', 'text', ...
                           'String', 'θ₁: 90°', ...
                           'Position', [410, 80, 60, 20], ...
                           'BackgroundColor', [0.9 0.9 0.9]);
    text_theta2 = uicontrol('Parent', fig, 'Style', 'text', ...
                           'String', 'θ₂: 0°', ...
                           'Position', [410, 50, 60, 20], ...
                           'BackgroundColor', [0.9 0.9 0.9]);
    
    % 音乐参数控制
    uicontrol('Parent', fig, 'Style', 'text', 'String', '摆1音域 (MIDI):', ...
              'Position', [500, 80, 80, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    edit_range1 = uicontrol('Parent', fig, 'Style', 'edit', ...
                           'String', '72-84', ...
                           'Position', [580, 80, 60, 20]);
    
    uicontrol('Parent', fig, 'Style', 'text', 'String', '摆2音域 (MIDI):', ...
              'Position', [500, 50, 80, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    edit_range2 = uicontrol('Parent', fig, 'Style', 'edit', ...
                           'String', '55-67', ...
                           'Position', [580, 50, 60, 20]);
    
    uicontrol('Parent', fig, 'Style', 'text', 'String', '速度 (BPM):', ...
              'Position', [660, 80, 60, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    edit_bpm = uicontrol('Parent', fig, 'Style', 'edit', ...
                        'String', '120', ...
                        'Position', [720, 80, 40, 20]);
    
    uicontrol('Parent', fig, 'Style', 'text', 'String', '音符密度:', ...
              'Position', [660, 50, 60, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    edit_density = uicontrol('Parent', fig, 'Style', 'edit', ...
                            'String', '8', ...
                            'Position', [720, 50, 40, 20]);
    
    % 控制按钮
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '开始模拟', ...
              'Position', [780, 80, 100, 40], 'Callback', @start_simulation);
    
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '生成音乐', ...
              'Position', [890, 80, 100, 40], 'Callback', @generate_music_callback);
          
    uicontrol('Parent', fig, 'Style', 'text', 'String', '音符长度(%):', ...
              'Position', [500, 20, 80, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    slider_note_length = uicontrol('Parent', fig, 'Style', 'slider', ...
                                  'Min', 10, 'Max', 100, 'Value', 30, ...
                                  'Position', [580, 20, 100, 20]);
    text_note_length = uicontrol('Parent', fig, 'Style', 'text', ...
                                'String', '30%', ...
                                'Position', [690, 20, 40, 20], ...
                                'BackgroundColor', [0.9 0.9 0.9]);

    % 滑块回调
    set(slider_note_length, 'Callback', @(src,event) set(text_note_length, 'String', ...
        sprintf('%d%%', round(get(src, 'Value')))));

    % 默认参数
    params.m1 = 1.0;  % 质量1 (kg)
    params.m2 = 1.0;  % 质量2 (kg)
    params.L1 = 1.0;  % 长度1 (m)
    params.L2 = 1.0;  % 长度2 (m)
    params.g = 9.81;  % 重力加速度 (m/s²)
    params.tspan = [0 20];  % 模拟时间 (s)
    params.fps = 30;  % 帧率 (Hz)
    
    % 轨迹参数
    params.trail_duration = 1.0;  % 轨迹总持续时间 (s)
    params.trail_fade_time = 0.5; % 轨迹淡出时间 (s)
    params.trail_width = 3;       % 轨迹初始宽度
    params.trail_min_width = 0.5; % 轨迹最小宽度
    
    % 存储图形对象
    handles.pendulum_arm1 = [];
    handles.pendulum_arm2 = [];
    handles.pendulum_bob1 = [];
    handles.pendulum_bob2 = [];
    handles.trail = [];
    handles.phase = [];
    handles.lyap = [];
    
    % 存储模拟数据
    sim_data.t = [];
    sim_data.theta1 = [];
    sim_data.theta2 = [];
    sim_data.lyap = [];
    sim_data.chaotic = false;
    
    % 更新参数函数
    function update_parameters(~, ~)
        theta1 = get(slider_theta1, 'Value');
        theta2 = get(slider_theta2, 'Value');
        set(text_theta1, 'String', sprintf('θ₁: %.1f°', theta1));
        set(text_theta2, 'String', sprintf('θ₂: %.1f°', theta2));
    end

    % 开始模拟函数
    function start_simulation(~, ~)
        % 清除之前的图形
        cla(ax_pendulum);
        cla(ax_phase);
        cla(ax_lyap);
        
        % 获取初始角度（转换为弧度）
        theta1_deg = get(slider_theta1, 'Value');
        theta2_deg = get(slider_theta2, 'Value');
        theta1_0 = deg2rad(theta1_deg);
        theta2_0 = deg2rad(theta2_deg);
        
        % 初始条件 [theta1, dtheta1/dt, theta2, dtheta2/dt]
        y0 = [theta1_0; 0; theta2_0; 0];
        
        % 解微分方程
        options = odeset('RelTol', 1e-6, 'AbsTol', 1e-9);
        [t, y] = ode45(@(t,y) double_pendulum_ode(t, y, params), params.tspan, y0, options);
        
        % 存储模拟数据
        sim_data.t = t;
        sim_data.theta1 = y(:,1);
        sim_data.theta2 = y(:,3);
        
        % 计算摆球位置
        x1 = params.L1 * sin(y(:,1));
        y1 = -params.L1 * cos(y(:,1));
        x2 = x1 + params.L2 * sin(y(:,3));
        y2 = y1 - params.L2 * cos(y(:,3));
        
        % 初始化图形对象
        hold(ax_pendulum, 'on');
        
        % 绘制固定点
        plot(ax_pendulum, 0, 0, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
        
        % 初始化摆臂和摆球
        handles.pendulum_arm1 = plot(ax_pendulum, [0, x1(1)], [0, y1(1)], 'b-', 'LineWidth', 2);
        handles.pendulum_arm2 = plot(ax_pendulum, [x1(1), x2(1)], [y1(1), y2(1)], 'r-', 'LineWidth', 2);
        handles.pendulum_bob1 = plot(ax_pendulum, x1(1), y1(1), 'bo', 'MarkerSize', 10+5*params.m1, 'MarkerFaceColor', 'b');
        handles.pendulum_bob2 = plot(ax_pendulum, x2(1), y2(1), 'ro', 'MarkerSize', 10+5*params.m2, 'MarkerFaceColor', 'r');
        
        % 初始化轨迹数据
        trail_data = struct('x', [], 'y', [], 't', [], 'width', []);
        
        % 初始化相图
        handles.phase = plot(ax_phase, y(1,1), y(1,3), 'b-');
        xlim(ax_phase, [-pi pi]);
        ylim(ax_phase, [-pi pi]);
        xticks(ax_phase, -pi:pi/2:pi);
        yticks(ax_phase, -pi:pi/2:pi);
        xticklabels(ax_phase, {'-π','-π/2','0','π/2','π'});
        yticklabels(ax_phase, {'-π','-π/2','0','π/2','π'});
        
        % 计算Lyapunov指数
        [lyap, t_lyap, is_chaotic] = calculate_lyapunov(y0, params);
        sim_data.lyap = lyap;
        sim_data.chaotic = is_chaotic;
        handles.lyap = plot(ax_lyap, t_lyap, lyap, 'b-');
        xlim(ax_lyap, [0, params.tspan(2)]);
        
        % 动画参数
        dt = 1/params.fps;
        [~, frame_indices] = histc(0:dt:params.tspan(2), t);
        
        % 动画循环
        for i = 1:length(frame_indices)
            idx = frame_indices(i);
            if idx == 0 || idx > length(t) || idx > length(x1) || idx > length(y1)
                continue; % 跳过无效索引
            end
            % 检查图形对象是否有效
            if ~isvalid(handles.pendulum_arm1) || ~isvalid(handles.pendulum_arm2)
                break; % 如果对象被删除，退出循环
            end
            % 更新摆臂位置
            set(handles.pendulum_arm1, 'XData', [0, x1(idx)], 'YData', [0, y1(idx)]);
            set(handles.pendulum_arm2, 'XData', [x1(idx), x2(idx)], 'YData', [y1(idx), y2(idx)]);
            
            % 更新摆球位置
            set(handles.pendulum_bob1, 'XData', x1(idx), 'YData', y1(idx));
            set(handles.pendulum_bob2, 'XData', x2(idx), 'YData', y2(idx));
            
            % 更新轨迹数据
            current_time = t(idx);
            trail_data.x(end+1) = x2(idx);
            trail_data.y(end+1) = y2(idx);
            trail_data.t(end+1) = current_time;
            trail_data.width(end+1) = params.trail_width;
            
            % 更新轨迹宽度和透明度
            fade_start_time = current_time - (params.trail_duration - params.trail_fade_time);
            fade_indices = find(trail_data.t < fade_start_time);
            
            if ~isempty(fade_indices)
                % 计算宽度衰减
                fade_amount = (fade_start_time - trail_data.t(fade_indices)) / params.trail_fade_time;
                trail_data.width(fade_indices) = max(params.trail_min_width, ...
                                                   params.trail_width * (1 - fade_amount));
                
                % 移除过期的点
                remove_idx = trail_data.width <= params.trail_min_width;
                trail_data.x(remove_idx) = [];
                trail_data.y(remove_idx) = [];
                trail_data.t(remove_idx) = [];
                trail_data.width(remove_idx) = [];
            end
            
            % 绘制轨迹（带有宽度变化）
            if length(trail_data.x) >= 2
                % 清除旧轨迹
                if ishandle(handles.trail)
                    delete(handles.trail);
                end
                
                % 绘制新轨迹（分段绘制实现宽度渐变）
                hold(ax_pendulum, 'on');
                handles.trail = gobjects(length(trail_data.x)-1, 1);
                for j = 1:length(trail_data.x)-1
                    handles.trail(j) = plot(ax_pendulum, trail_data.x(j:j+1), trail_data.y(j:j+1), ...
                                          'r-', 'LineWidth', trail_data.width(j));
                end
            end
            
            % 更新相图
            set(handles.phase, 'XData', y(1:idx,1), 'YData', y(1:idx,3));
            
            % 更新Lyapunov指数图
            [~, lyap_idx] = histc(t(idx), t_lyap);
            if lyap_idx > 0
                set(handles.lyap, 'XData', t_lyap(1:lyap_idx), 'YData', lyap(1:lyap_idx));
            end
            
            % 刷新图形
            drawnow;
            
            % 暂停以控制帧率
            pause(dt);
        end
    end

    % 生成音乐回调函数 - 修复版
    % 在generate_music_callback函数中添加计算
    function generate_music_callback(~, ~)
        if isempty(sim_data.t)
            msgbox('请先进行模拟', '提示');
            return;
        end

        % 让用户选择保存位置
        path = uigetdir('', '选择MIDI文件保存位置');
        if path == 0
            return;
        end

        % 读取音乐参数
        try
            bpm_str = get(edit_bpm, 'String');
            bpm = str2double(bpm_str);
            if isnan(bpm) || bpm <= 0
                bpm = 120;
            end

            density_str = get(edit_density, 'String');
            density = str2double(density_str);
            if isnan(density) || density <= 0
                density = 16; % 默认十六分音符，更密集
            end
            note_division = 1 / density;

            % 解析音域范围
            range1_str = get(edit_range1, 'String');
            range2_str = get(edit_range2, 'String');
            range1 = sscanf(range1_str, '%d-%d')';
            range2 = sscanf(range2_str, '%d-%d')';

            if isempty(range1) || length(range1) ~= 2
                range1 = [72, 84];
            end
            if isempty(range2) || length(range2) ~= 2
                range2 = [55, 67];
            end

        catch
            errordlg('参数解析错误，使用默认值', '错误');
            bpm = 120;
            note_division = 1/16; % 更短的音符
            range1 = [72, 84];
            range2 = [55, 67];
        end

       % 读取音符长度系数（转换为0-1的小数）
        note_length_percent = get(slider_note_length, 'Value');
        note_length_ratio = note_length_percent / 100;

        % 生成两个独立的MIDI文件
        try
            y_data = [sim_data.theta1, gradient(sim_data.theta1, sim_data.t), ...
                      sim_data.theta2, gradient(sim_data.theta2, sim_data.t)];

            % 摆1的MIDI
            filename1 = fullfile(path, 'pendulum_1.mid');
            generate_single_midi_fixed(sim_data.t, y_data(:,1:2), range1, bpm, note_division, filename1, 1, note_length_ratio);

            % 摆2的MIDI  
            filename2 = fullfile(path, 'pendulum_2.mid');
            generate_single_midi_fixed(sim_data.t, y_data(:,3:4), range2, bpm, note_division, filename2, 2, note_length_ratio);

            msgbox(sprintf('两个MIDI文件已生成:\n%s\n%s', filename1, filename2), '完成');

        catch ME
            errordlg(sprintf('生成MIDI时出错:\n%s', ME.message), '错误');
        end
    end

    % 双摆微分方程
    function dydt = double_pendulum_ode(~, y, p)
        theta1 = y(1);
        theta1_dot = y(2);
        theta2 = y(3);
        theta2_dot = y(4);
        
        delta = theta2 - theta1;
        
        % 双摆运动方程
        den1 = (p.m1 + p.m2)*p.L1 - p.m2*p.L1*cos(delta)*cos(delta);
        den2 = (p.L2/p.L1)*den1;
        
        theta1_ddot = (p.m2*p.L1*theta1_dot*theta1_dot*sin(delta)*cos(delta) ...
                      + p.m2*p.g*sin(theta2)*cos(delta) ...
                      + p.m2*p.L2*theta2_dot*theta2_dot*sin(delta) ...
                      - (p.m1 + p.m2)*p.g*sin(theta1));
        theta1_ddot = theta1_ddot / den1;
        
        theta2_ddot = (-p.m2*p.L2*theta2_dot*theta2_dot*sin(delta)*cos(delta) ...
                      + (p.m1 + p.m2)*p.g*sin(theta1)*cos(delta) ...
                      - (p.m1 + p.m2)*p.L1*theta1_dot*theta1_dot*sin(delta) ...
                      - (p.m1 + p.m2)*p.g*sin(theta2));
        theta2_ddot = theta2_ddot / den2;
        
        dydt = [theta1_dot; theta1_ddot; theta2_dot; theta2_ddot];
    end

    % Lyapunov指数计算
    function [lyap, t_lyap, is_chaotic] = calculate_lyapunov(y0, p)
        % 检查是否为静止状态
        is_upright_still = all(abs(y0([2,4])) < 1e-3) && all(abs(y0([1,3])) < 1e-3);
        is_inverted_still = all(abs(y0([2,4])) < 1e-3) && ...
                           all(abs(y0([1])-pi) < 1e-3) && ...
                           all(abs(y0([3])-pi) < 1e-3);
        
        if is_upright_still || is_inverted_still
            t_lyap = linspace(0, p.tspan(2), 100);
            lyap = zeros(size(t_lyap));
            is_chaotic = false;
            return;
        end
        
        % 模拟主轨迹
        [t_main, y_main] = ode45(@(t,y) double_pendulum_ode(t,y,p), p.tspan, y0);
        
        % 创建微小扰动的轨迹
        epsilon = 1e-8;
        perturbation = epsilon * [0.3; 0.1; -0.2; 0.05];
        y0_perturbed = y0 + perturbation;
        
        [t_pert, y_pert] = ode45(@(t,y) double_pendulum_ode(t,y,p), p.tspan, y0_perturbed);
        
        % 对齐时间点
        [t_common, idx_main, idx_pert] = intersect(t_main, t_pert);
        
        % 计算距离（考虑角度周期性）
        delta_theta1 = mod(y_main(idx_main,1) - y_pert(idx_pert,1) + pi, 2*pi) - pi;
        delta_theta2 = mod(y_main(idx_main,3) - y_pert(idx_pert,3) + pi, 2*pi) - pi;
        delta_omega1 = y_main(idx_main,2) - y_pert(idx_pert,2);
        delta_omega2 = y_main(idx_main,4) - y_pert(idx_pert,4);
        
        distances = sqrt(0.5*delta_theta1.^2 + 0.5*delta_theta2.^2 + 0.05*delta_omega1.^2 + 0.05*delta_omega2.^2);
        
        % 计算Lyapunov指数
        lyap = zeros(size(t_common));
        for i = 2:length(t_common)
            dt = t_common(i) - t_common(1);
            if distances(i) > 0
                lyap(i) = log(distances(i)/norm(perturbation))/dt;
            else
                lyap(i) = lyap(i-1);
            end
        end
        
        % 平滑处理
        window_size = max(5, min(20, floor(length(lyap)/20)));
        if window_size > 1
            lyap = movmean(lyap, window_size);
        end
        
        t_lyap = t_common;
        
        % 判断是否混沌（最后1/3时间段平均Lyapunov指数）
        final_third = floor(2*length(lyap)/3):length(lyap);
        mean_lyap = mean(lyap(final_third));
        is_chaotic = mean_lyap > 0.02;
    end

    % 生成MIDI文件函数（独立音轨版本）- 修复版
    function generate_single_midi_fixed(t, y_data, note_range, bpm, note_division, filename, pendulum_num, note_length_ratio)
        % 修正版：确保音符有明确的结束时间

        sec_per_beat = 60 / bpm;
        sec_per_note = sec_per_beat * note_division;

        total_time = t(end) - t(1);
        max_notes = min(2000, floor(total_time / sec_per_note));
        note_times = t(1) + (0:max_notes-1) * sec_per_note;
        note_times = note_times(note_times <= t(end));

        % 插值数据
        theta_interp = interp1(t, y_data(:,1), note_times, 'linear', 'extrap');
        omega_interp = interp1(t, abs(y_data(:,2)), note_times, 'linear', 'extrap');

        % 映射音高和力度
        norm_theta = (theta_interp - min(theta_interp)) / (max(theta_interp) - min(theta_interp) + eps);
        pitches = round(note_range(1) + norm_theta * (note_range(2) - note_range(1)));
        velocities = round(40 + min(80, omega_interp * 15));

        % 创建MIDI矩阵 - 确保每个音符都有明确的持续时间
        midi_matrix = [];
        current_note = struct('pitch', 0, 'velocity', 0, 'start_time', 0, 'active', false);

        for i = 1:length(note_times)
            current_time = (i-1) * note_division;
            
            % 检查是否需要结束上一个音符
            if current_note.active && (i > 1)
                % 结束上一个音符
                note_duration = note_division * note_length_ratio;
                midi_matrix = [midi_matrix; 
                              1, pendulum_num, current_note.pitch, 0, current_time, 0];
                current_note.active = false;
            end
            
            % 检查是否需要开始新音符
            if omega_interp(i) > 0.5 % 触发阈值
                % 开始新音符
                midi_matrix = [midi_matrix; 
                              1, pendulum_num, pitches(i), velocities(i), current_time, 0];
                current_note.pitch = pitches(i);
                current_note.velocity = velocities(i);
                current_note.start_time = current_time;
                current_note.active = true;
            end
        end

        % 结束最后一个音符（如果有）
        if current_note.active
            end_time = length(note_times) * note_division;
            midi_matrix = [midi_matrix; 
                          1, pendulum_num, current_note.pitch, 0, end_time, 0];
        end

        % 写入MIDI文件
        if ~isempty(midi_matrix)
            % 按时间排序事件
            [~, sort_idx] = sort(midi_matrix(:,5));
            midi_matrix = midi_matrix(sort_idx, :);
            
            midi = matrix2midi(midi_matrix, bpm);
            writemidi(midi, filename);
        else
            warndlg('没有生成任何音符', '警告');
        end
    end

    
end