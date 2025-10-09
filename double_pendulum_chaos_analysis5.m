function double_pendulum_chaos_analysis5()
    % 创建主界面
    fig = figure('Name', '双摆混沌行为分析', 'NumberTitle', 'off', ...
                 'Position', [100, 100, 1200, 800], 'Color', [0.95 0.95 0.95]);
    
    % 创建双摆动画区域
    ax_pendulum = axes('Parent', fig, 'Position', [0.05 0.35 0.4 0.6]);
    axis(ax_pendulum, 'equal');
    xlim(ax_pendulum, [-2.5 2.5]);
    ylim(ax_pendulum, [-2.5 2.5]);
    title(ax_pendulum, '双摆运动模拟');
    grid(ax_pendulum, 'on');
    hold(ax_pendulum, 'on');
    
    % 创建相图区域
    ax_phase = axes('Parent', fig, 'Position', [0.55 0.35 0.4 0.3]);
    title(ax_phase, '相空间轨迹 (θ₁ vs θ₂)');
    xlabel(ax_phase, 'θ₁ (rad)');
    ylabel(ax_phase, 'θ₂ (rad)');
    grid(ax_phase, 'on');
    hold(ax_phase, 'on');
    
    % 创建混沌区域图
    ax_chaos = axes('Parent', fig, 'Position', [0.55 0.7 0.4 0.25]);
    title(ax_chaos, '混沌区域图');
    xlabel(ax_chaos, '初始θ₁ (度)');
    ylabel(ax_chaos, '初始θ₂ (度)');
    axis(ax_chaos, 'equal');
    hold(ax_chaos, 'on');
    
    % 控制面板
    uipanel('Parent', fig, 'Title', '控制面板', ...
            'Position', [0.05 0.05 0.9 0.25], 'BackgroundColor', [0.9 0.9 0.9]);
    
    % 初始角度滑块
    uicontrol('Parent', fig, 'Style', 'text', 'String', '初始角度 θ₁ (度):', ...
              'Position', [70, 150, 120, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    slider_theta1 = uicontrol('Parent', fig, 'Style', 'slider', ...
                             'Min', -180, 'Max', 180, 'Value', 90, ...
                             'Position', [200, 150, 200, 20], ...
                             'Callback', @update_parameters);
    uicontrol('Parent', fig, 'Style', 'edit', ...
              'String', '90', ...
              'Position', [480, 150, 50, 20], ...
              'Tag', 'edit_theta1', ...
              'Callback', @edit_theta_callback);
    
    uicontrol('Parent', fig, 'Style', 'text', 'String', '初始角度 θ₂ (度):', ...
              'Position', [70, 120, 120, 20], 'BackgroundColor', [0.9 0.9 0.9]);
    slider_theta2 = uicontrol('Parent', fig, 'Style', 'slider', ...
                             'Min', -180, 'Max', 180, 'Value', 0, ...
                             'Position', [200, 120, 200, 20], ...
                             'Callback', @update_parameters);
    uicontrol('Parent', fig, 'Style', 'edit', ...
              'String', '0', ...
              'Position', [480, 120, 50, 20], ...
              'Tag', 'edit_theta2', ...
              'Callback', @edit_theta_callback);
    
    % 显示当前角度值
    text_theta1 = uicontrol('Parent', fig, 'Style', 'text', ...
                           'String', 'θ₁: 90°', ...
                           'Position', [410, 150, 60, 20], ...
                           'BackgroundColor', [0.9 0.9 0.9]);
    text_theta2 = uicontrol('Parent', fig, 'Style', 'text', ...
                           'String', 'θ₂: 0°', ...
                           'Position', [410, 120, 60, 20], ...
                           'BackgroundColor', [0.9 0.9 0.9]);
    
    % 控制按钮
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '开始模拟', ...
              'Position', [600, 150, 100, 40], 'Callback', @start_simulation);
    
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '混沌分析', ...
              'Position', [720, 150, 100, 40], 'Callback', @chaos_analysis);
    
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', '生成混沌图', ...
              'Position', [840, 150, 120, 40], 'Callback', @generate_chaos_map);
    
    % 相位限制选项
    uicontrol('Parent', fig, 'Style', 'checkbox', 'String', '限制相位(-π~π)', ...
              'Position', [500, 100, 150, 20], 'Value', 1, ...
              'Callback', @toggle_phase_limit, 'BackgroundColor', [0.9 0.9 0.9]);
    
    % 参数显示
    text_info = uicontrol('Parent', fig, 'Style', 'text', ...
                         'String', '准备就绪', ...
                         'Position', [500, 60, 360, 30], ...
                         'BackgroundColor', [0.9 0.9 0.9]);
    
    % 双摆参数
    params.m1 = 1.0;  % 质量1
    params.m2 = 1.0;  % 质量2
    params.L1 = 1.0;  % 长度1
    params.L2 = 1.0;  % 长度2
    params.g = 9.81;  % 重力加速度
    params.tspan = [0 20];  % 模拟时间
    params.fps = 30;  % 帧率
    params.phase_limit = true; % 相位限制标志
    
    % 存储图形对象
    handles.pendulum_arm1 = [];
    handles.pendulum_arm2 = [];
    handles.pendulum_bob1 = [];
    handles.pendulum_bob2 = [];
    handles.trail = [];
    handles.phase = [];
    handles.chaos_img = [];
    
    % 存储模拟数据
    sim_data.t = [];
    sim_data.theta1 = [];
    sim_data.theta2 = [];
    sim_data.chaotic = false;
    
    % 初始化编辑框的UserData
    edit_theta1 = findobj(fig, 'Tag', 'edit_theta1');
    edit_theta2 = findobj(fig, 'Tag', 'edit_theta2');
    set(edit_theta1, 'UserData', 90);
    set(edit_theta2, 'UserData', 0);
    
    % 更新参数函数
    function update_parameters(~, ~)
        theta1 = get(slider_theta1, 'Value');
        theta2 = get(slider_theta2, 'Value');
        set(text_theta1, 'String', sprintf('θ₁: %.2f°', theta1));
        set(text_theta2, 'String', sprintf('θ₂: %.2f°', theta2));
        
        % 更新编辑框
        edit_theta1 = findobj(fig, 'Tag', 'edit_theta1');
        edit_theta2 = findobj(fig, 'Tag', 'edit_theta2');
        set(edit_theta1, 'String', num2str(theta1));
        set(edit_theta1, 'UserData', theta1);
        set(edit_theta2, 'String', num2str(theta2));
        set(edit_theta2, 'UserData', theta2);
    end

    % 编辑框回调函数
    function edit_theta_callback(src, ~)
        % 获取编辑框的值
        val = str2double(get(src, 'String'));
        
        % 验证输入
        if isnan(val) || val < -180 || val > 180
            set(src, 'String', num2str(get(src, 'UserData')));
            return;
        end
        
        % 根据是哪个编辑框来更新滑块和显示
        if strcmp(get(src, 'Tag'), 'edit_theta1')
            set(slider_theta1, 'Value', val);
            set(text_theta1, 'String', sprintf('θ₁: %.2f°', val));
        else
            set(slider_theta2, 'Value', val);
            set(text_theta2, 'String', sprintf('θ₂: %.2f°', val));
        end
        
        % 存储当前有效值
        set(src, 'UserData', val);
    end

    % 切换相位限制
    function toggle_phase_limit(src, ~)
        params.phase_limit = get(src, 'Value');
        if params.phase_limit
            set(text_info, 'String', '相位限制已启用: 角度将保持在[-π,π]范围内');
        else
            set(text_info, 'String', '相位限制已禁用: 角度可以自由增长');
        end
    end

    % 开始模拟函数
    function start_simulation(~, ~)
        % 清除之前的图形
        cla(ax_pendulum);
        cla(ax_phase);
        hold(ax_pendulum, 'on');
        hold(ax_phase, 'on');
        
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
        
        % 应用相位限制
        if params.phase_limit
            y(:,1) = mod(y(:,1)+pi, 2*pi)-pi;
            y(:,3) = mod(y(:,3)+pi, 2*pi)-pi;
        end
        
        % 存储模拟数据
        sim_data.t = t;
        sim_data.theta1 = y(:,1);
        sim_data.theta2 = y(:,3);
        
        % 计算摆球位置
        x1 = params.L1 * sin(y(:,1));
        y1 = -params.L1 * cos(y(:,1));
        x2 = x1 + params.L2 * sin(y(:,3));
        y2 = y1 - params.L2 * cos(y(:,3));
        
        % 绘制固定点
        plot(ax_pendulum, 0, 0, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
        
        % 初始化摆臂和摆球
        handles.pendulum_arm1 = plot(ax_pendulum, [0, x1(1)], [0, y1(1)], 'b-', 'LineWidth', 2);
        handles.pendulum_arm2 = plot(ax_pendulum, [x1(1), x2(1)], [y1(1), y2(1)], 'r-', 'LineWidth', 2);
        handles.pendulum_bob1 = plot(ax_pendulum, x1(1), y1(1), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
        handles.pendulum_bob2 = plot(ax_pendulum, x2(1), y2(1), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
        
        % 初始化轨迹
        handles.trail = plot(ax_pendulum, x2(1), y2(1), 'r-', 'LineWidth', 1);
        
        % 初始化相图
        handles.phase = plot(ax_phase, y(1,1), y(1,3), 'b.');
        xlim(ax_phase, [-pi pi]);
        ylim(ax_phase, [-pi pi]);
        xticks(ax_phase, -pi:pi/2:pi);
        yticks(ax_phase, -pi:pi/2:pi);
        xticklabels(ax_phase, {'-π','-π/2','0','π/2','π'});
        yticklabels(ax_phase, {'-π','-π/2','0','π/2','π'});
        
        % 动画参数
        dt = 1/params.fps;
        [~, frame_indices] = histc(0:dt:params.tspan(2), t);
        
        % 动画循环
        for i = 1:length(frame_indices)
            idx = frame_indices(i);
            if idx == 0, continue; end
            
            % 更新摆臂位置
            set(handles.pendulum_arm1, 'XData', [0, x1(idx)], 'YData', [0, y1(idx)]);
            set(handles.pendulum_arm2, 'XData', [x1(idx), x2(idx)], 'YData', [y1(idx), y2(idx)]);
            
            % 更新摆球位置
            set(handles.pendulum_bob1, 'XData', x1(idx), 'YData', y1(idx));
            set(handles.pendulum_bob2, 'XData', x2(idx), 'YData', y2(idx));
            
            % 更新轨迹
            set(handles.trail, 'XData', x2(1:idx), 'YData', y2(1:idx));
            
            % 更新相图
            set(handles.phase, 'XData', y(1:idx,1), 'YData', y(1:idx,3));
            
            % 刷新图形
            drawnow;
            
            % 暂停以控制帧率
            pause(dt);
        end
        
        % 分析混沌行为
        analyze_chaos(y);
    end

    % 双摆微分方程（带相位限制选项）
    function dydt = double_pendulum_ode(~, y, p)
        theta1 = y(1);
        theta1_dot = y(2);
        theta2 = y(3);
        theta2_dot = y(4);
        
        % 应用相位限制（在微分方程中保持连续性）
        if p.phase_limit
            theta1 = mod(theta1+pi, 2*pi)-pi;
            theta2 = mod(theta2+pi, 2*pi)-pi;
        end
        
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

    % 混沌分析函数
    function chaos_analysis(~, ~)
        if isempty(sim_data.t)
            set(text_info, 'String', '请先进行模拟');
            return;
        end
        
        % 计算最大Lyapunov指数（简化版）
        max_lyap = estimate_lyapunov(sim_data.theta1, sim_data.theta2, sim_data.t);
        
        if max_lyap > 0.05
            set(text_info, 'String', sprintf('混沌状态 detected! 最大Lyapunov指数: %.3f', max_lyap));
            sim_data.chaotic = true;
        else
            set(text_info, 'String', sprintf('规则运动 detected! 最大Lyapunov指数: %.3f', max_lyap));
            sim_data.chaotic = false;
        end
    end

    % 生成混沌区域图
    function generate_chaos_map(~, ~)
        set(text_info, 'String', '正在生成混沌区域图，请稍候...');
        drawnow;
        
        % 参数设置
        resolution = 100; % 图像分辨率
        theta1_range = linspace(-180, 180, resolution);
        theta2_range = linspace(-180, 180, resolution);
        chaos_map = zeros(resolution);
        
        % 模拟时间缩短以提高速度
        tspan = [0 10];
        options = odeset('RelTol', 1e-4, 'AbsTol', 1e-6);
        
        % 遍历所有初始条件
        for i = 1:resolution
            for j = 1:resolution
                % 初始角度（转换为弧度）
                theta1_0 = deg2rad(theta1_range(i));
                theta2_0 = deg2rad(theta2_range(j));
                
                % 初始条件 [theta1, dtheta1/dt, theta2, dtheta2/dt]
                y0 = [theta1_0; 0; theta2_0; 0];
                
                % 解微分方程
                [~, y] = ode45(@(t,y) double_pendulum_ode(t, y, params), tspan, y0, options);
                
                % 应用相位限制
                if params.phase_limit
                    y(:,1) = mod(y(:,1)+pi, 2*pi)-pi;
                    y(:,3) = mod(y(:,3)+pi, 2*pi)-pi;
                end
                
                % 计算混沌指标（简化版：使用角度变化的方差）
                var_theta1 = var(y(end-round(end/3):end, 1));
                var_theta2 = var(y(end-round(end/3):end, 3));
                chaos_map(i,j) = log(1 + var_theta1 + var_theta2);
            end
            % 更新进度
            if mod(i, 10) == 0
                set(text_info, 'String', sprintf('生成混沌图中... %.1f%% 完成', i/resolution*100));
                drawnow;
            end
        end
        
        % 显示混沌图
        cla(ax_chaos);
        imagesc(ax_chaos, theta1_range, theta2_range, chaos_map');
        axis(ax_chaos, 'xy');
        colorbar(ax_chaos);
        title(ax_chaos, '混沌区域图 (亮度越高越混沌)');
        xlabel(ax_chaos, '初始θ₁ (度)');
        ylabel(ax_chaos, '初始θ₂ (度)');
        
        set(text_info, 'String', '混沌区域图生成完成！');
    end

    % 辅助函数：估计Lyapunov指数（简化版）
    function max_lyap = estimate_lyapunov(theta1, theta2, t)
        % 使用两个相邻轨迹的分离速率估计Lyapunov指数
        if length(theta1) < 100
            max_lyap = 0;
            return;
        end
        
        % 计算角度变化的导数
        dtheta1 = diff(theta1);
        dtheta2 = diff(theta2);
        dt = mean(diff(t));
        
        % 计算分离距离
        distances = sqrt(dtheta1.^2 + dtheta2.^2);
        
        % 计算Lyapunov指数估计
        lyap = zeros(size(distances));
        for i = 2:length(distances)
            if distances(i) > 0 && distances(1) > 0
                lyap(i) = log(distances(i)/distances(1))/(t(i)-t(1));
            end
        end
        
        % 取最后1/3的平均值
        final_third = round(2*length(lyap)/3):length(lyap);
        max_lyap = mean(lyap(final_third));
    end

    % 辅助函数：分析混沌行为
    function analyze_chaos(y)
        % 计算轨迹的对称性指标
        theta1 = y(:,1);
        theta2 = y(:,3);
        
        % 计算轨迹的"最远点"
        distances = theta1.^2 + theta2.^2;
        [~, max_idx] = max(distances);
        max_point = [theta1(max_idx), theta2(max_idx)];
        
        % 检查最远点是否在混沌区域内（简化版）
        if norm(max_point) < pi/2
            symmetry = '高对称性';
            sim_data.chaotic = false;
        else
            symmetry = '低对称性(可能混沌)';
            sim_data.chaotic = true;
        end
        
        set(text_info, 'String', sprintf('对称性分析: %s | 最远点: (%.2f, %.2f)', ...
            symmetry, max_point(1), max_point(2)));
    end
end