function double_pendulum_chaos_map11()
    % 创建主界面
    fig = figure('Name', '双摆混沌区域可视化 (最终版)', 'NumberTitle', 'off', ...
                 'Position', [100, 100, 1200, 800], 'Color', [0.95 0.95 0.95]);

    % 创建混沌区域图
    ax_chaos = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.1 0.2 0.6 0.7]);
    title(ax_chaos, '双摆混沌区域图');
    xlabel(ax_chaos, '初始θ₁ (度)');
    ylabel(ax_chaos, '初始θ₂ (度)');
    axis(ax_chaos, 'equal');
    hold(ax_chaos, 'on');
    marker_layer = plot(ax_chaos, NaN, NaN, 'wo', 'MarkerSize', 8, 'Visible', 'off'); 
    text_layer = gobjects(0); % 文本标签句柄数组
    
    
    %固定图像
    set(ax_chaos, 'DataAspectRatio', [1 1 1], 'XLim', [-180 180], 'YLim', [-180 180]);
    hold(ax_chaos, 'on');
    chaos_img = imagesc(ax_chaos, [-180 180], [-180 180], zeros(360));
    
    % 存储所有标记点句柄
    marker_handles = gobjects(0); 
    hold(ax_chaos, 'off');
    
    % 创建比对轨迹图
    ax_trace = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.75 0.5 0.2 0.4]);
    title(ax_trace, '比对轨迹');
    xlabel(ax_trace, 'θ₁ (rad)');
    ylabel(ax_trace, 'θ₂ (rad)');
    grid(ax_trace, 'on');
    hold(ax_trace, 'on');
    
    eraser_mode = false;

    % 创建控制面板
    control_panel = uipanel('Parent', fig, 'Title', '控制面板', 'Units', 'normalized', ...
                           'Position', [0.75 0.1 0.2 0.3], 'BackgroundColor', [0.9 0.9 0.9]);
    
    % 分辨率设置
    uicontrol('Parent', control_panel, 'Style', 'text', 'String', '分辨率:', ...
              'Units', 'normalized', 'Position', [0.1 0.9 0.4 0.1], ...
              'BackgroundColor', [0.9 0.9 0.9]);
    res_slider = uicontrol('Parent', control_panel, 'Style', 'slider', ...
                          'Units', 'normalized', 'Position', [0.5 0.9 0.4 0.1], ...
                          'Min', 20, 'Max', 4000, 'Value', 100, 'Tag', 'res_slider');
    res_edit = uicontrol('Parent', control_panel, 'Style', 'edit', ...
                        'Units', 'normalized', 'Position', [0.9 0.9 0.1 0.1], ...
                        'String', '100', 'Tag', 'res_edit', ...
                        'Callback', @(src,~) validate_input(src, res_slider, 20, 4000));

    % 模拟时间设置
    uicontrol('Parent', control_panel, 'Style', 'text', 'String', '模拟时间(s):', ...
              'Units', 'normalized', 'Position', [0.1 0.78 0.4 0.1], ...
              'BackgroundColor', [0.9 0.9 0.9]);
    time_slider = uicontrol('Parent', control_panel, 'Style', 'slider', ...
                          'Units', 'normalized', 'Position', [0.5 0.78 0.4 0.1], ...
                          'Min', 5, 'Max', 30, 'Value', 10, 'Tag', 'time_slider');
    time_edit = uicontrol('Parent', control_panel, 'Style', 'edit', ...
                         'Units', 'normalized', 'Position', [0.9 0.78 0.1 0.1], ...
                         'String', '10', 'Tag', 'time_edit', ...
                         'Callback', @(src,~) validate_input(src, time_slider, 5, 30));
    % mt1设置
    uicontrol('Parent', control_panel, 'Style', 'text', 'String', 'mt1(g):', ...
              'Units', 'normalized', 'Position', [0.1 0.55 0.4 0.1], ...
              'BackgroundColor', [0.9 0.9 0.9]);
    mt1_slider = uicontrol('Parent', control_panel, 'Style', 'slider', ...
                          'Units', 'normalized', 'Position', [0.5 0.55 0.4 0.1], ...
                          'Min', 1, 'Max', 30, 'Value', 1, 'Tag', 'mt1_slider');
    mt1_edit = uicontrol('Parent', control_panel, 'Style', 'edit', ...
                         'Units', 'normalized', 'Position', [0.9 0.55 0.1 0.1], ...
                         'String', '1', 'Tag', 'time_edit', ...
                         'Callback', @(src,~) validate_input(src, mt1_slider, 1, 30));
                     
    % 橡皮擦半径设置
    uicontrol('Parent', control_panel, 'Style', 'text', 'String', '橡皮擦半径:', ...
              'Units', 'normalized', 'Position', [0.1 0.66 0.4 0.1], ...
              'BackgroundColor', [0.9 0.9 0.9]);
    eraser_slider = uicontrol('Parent', control_panel, 'Style', 'slider', ...
                             'Units', 'normalized', 'Position', [0.5 0.66 0.4 0.1], ...
                             'Min', 1, 'Max', 50, 'Value', 10, 'Tag', 'eraser_slider');
    eraser_edit = uicontrol('Parent', control_panel, 'Style', 'edit', ...
                           'Units', 'normalized', 'Position', [0.9 0.66 0.1 0.1], ...
                           'String', '10', 'Tag', 'eraser_edit', ...
                           'Callback', @(src,~) validate_input(src, eraser_slider, 1, 50));
                       
    % 混沌指标类型
    uicontrol('Parent', control_panel, 'Style', 'text', 'String', '混沌指标:', ...
              'Units', 'normalized', 'Position', [0.1 0.535 0.4 0.1], ...
              'BackgroundColor', [0.9 0.9 0.9]);
    chaos_type = uicontrol('Parent', control_panel, 'Style', 'popupmenu', ...
                          'Units', 'normalized', 'Position', [0.5 0.55 0.4 0.1], ...
                          'String', {'角度方差', '李雅普诺夫指数', '能量变化'}, 'Value', 1);
    
    % 控制按钮
    btn_width = 0.4;
    btn_height = 0.13;
    
    uicontrol('Parent', control_panel, 'Style', 'pushbutton', 'String', '开始生成', ...
              'Units', 'normalized', 'Position', [0.05 0.25 btn_width btn_height], ...
              'Callback', @start_generation);
    
    uicontrol('Parent', control_panel, 'Style', 'pushbutton', 'String', '添加比对轨迹', ...
              'Units', 'normalized', 'Position', [0.55 0.25 btn_width btn_height], ...
              'Callback', @add_comparison);
    
    uicontrol('Parent', control_panel, 'Style', 'pushbutton', 'String', '保存图像', ...
              'Units', 'normalized', 'Position', [0.05 0.1 btn_width btn_height], ...
              'Callback', @save_image);

    uicontrol('Parent', control_panel, 'Style', 'pushbutton',...
              'String', '清除所有轨迹',...
              'Units', 'normalized',...
              'Position', [0.05 0.4 btn_width btn_height],...
              'Callback', @clearAllTraces);
    uicontrol('Parent', control_panel, 'Style', 'pushbutton',...
              'String', '橡皮擦模式',...
              'Units', 'normalized',...
              'Position', [0.55 0.4 btn_width btn_height],...
              'Callback', @toggle_eraser_mode,...
              'Tag', 'eraser_btn');

    % 状态信息
    info_text = uicontrol('Parent', control_panel, 'Style', 'text', ...
                         'String', '准备就绪', 'Units', 'normalized', ...
                         'Position', [0.05 0.01 0.9 0.08], ...
                         'BackgroundColor', [0.9 0.9 0.9]);
    
    % 滑块回调函数
    set(res_slider, 'Callback', @(src,~) set(res_edit, 'String', num2str(round(get(src,'Value')))));
    set(time_slider, 'Callback', @(src,~) set(time_edit, 'String', num2str(get(src,'Value'))));
    set(mt1_slider, 'Callback', @(src,~) set(mt1_edit, 'String', num2str(get(src,'Value'))));
    set(eraser_slider, 'Callback', @(src,~) set(eraser_edit, 'String', num2str(round(get(src,'Value')))));
    
    % 寻找轨迹按钮
    uicontrol('Parent', control_panel, 'Style', 'pushbutton',...
              'String', '寻找轨迹', 'Units', 'normalized',...
              'Position', [0.55 0.1 btn_width btn_height],...
              'Callback', @toggle_trace_selection,...
              'Tag', 'trace_selector_btn');
    
    % 角度坐标显示器
    coord_display = uicontrol('Parent', fig, 'Style', 'text',...
                            'String', '当前坐标: 未选择',...
                            'Units', 'normalized',...
                            'Position', [0.75 0.4 0.2 0.05],...
                            'BackgroundColor', [0.9 0.9 0.9],...
                            'FontWeight', 'bold',...
                            'HorizontalAlignment', 'center');
    
%     % 进度提示系统初始化
%     progress_stages = [1:10, 20:10:90, 100];
%     last_reported = 0;
%     
    % 添加新状态变量
    trace_selection_mode = false;
    current_coords = [NaN, NaN];

    
    % 双摆参数
%     params.m1 = mt1;  % 质量1
    params.m2 = 1.0;  % 质量2
    params.L1 = 1.0;  % 长度1
    params.L2 = 1.0;  % 长度2
    params.g = 9.81;  % 重力加速度

    % 存储数据
    chaos_data = struct();
    comparison_traces = {};
    chaos_img = [];
    
    % 开始生成混沌图
    function start_generation(~, ~)
        % 初始化进度
        resolution = max(20, min(4000, round(str2double(get(res_edit, 'String')))));
        sim_time = max(5, min(30, str2double(get(time_edit, 'String'))));
        m1 = max(1, min(30, str2double(get(mt1_edit, 'String'))));
        chaos_type_idx = get(chaos_type, 'Value');
        set(info_text, 'String', '正在生成混沌图...');
        drawnow;

        % 初始化混沌图数据
        theta1_range = linspace(-180, 180, resolution);
        theta2_range = linspace(-180, 180, resolution);
        theta1_rad = deg2rad(theta1_range);
        theta2_rad = deg2rad(theta2_range);

        % 预分配结果数组
        chaos_index = zeros(resolution, resolution);

        % 设置ODE选项
        options = odeset('RelTol', 1e-6, 'AbsTol', 1e-9);

%         % 将参数转换为适合并行处理的格式
%         m1 = params.m1;
%         m2 = params.m2;
%         L1 = params.L1;
%         L2 = params.L2;
%         g = params.g;

        % 初始化图形
        if isempty(chaos_img) || ~isvalid(chaos_img)
            % 首次创建图像对象
            chaos_img = imagesc(ax_chaos, theta1_range, theta2_range, chaos_index);
            axis(ax_chaos, 'xy');
            colorbar(ax_chaos);
            colormap(ax_chaos, 'jet');
            hold(ax_chaos, 'on');
            marker_layer = plot(ax_chaos, NaN, NaN, 'wo', 'MarkerSize', 8, 'Visible', 'off');
            hold(ax_chaos, 'off');
        else
            % 仅更新数据
            set(chaos_img, 'XData', theta1_range, 'YData', theta2_range);
        end
        title(ax_chaos, '双摆混沌区域图 (生成中...)');

        % 使用并行计算加速
        try
            % 检查并行池
            persistent firstRun ;
            if isempty(gcp('nocreate'))
                parpool;
            end
            firstRun = false;

%             % 预计算所有初始角度
%             theta1_rad = deg2rad(theta1_range);
%             theta2_rad = deg2rad(theta2_range);

            % 并行计算每行的混沌指标
%             m1 = params.m1; 
            m2 = params.m2;
            L1 = params.L1; 
            L2 = params.L2;
            g = params.g;

            parfor i = 1:resolution
                row_chaos = zeros(1, resolution);
                theta1 = theta1_rad(i);

                for j = 1:resolution
                    y0 = [theta1; 0; theta2_rad(j); 0];
                    [~, y] = ode45(@(t,y) external_dp_ode(t,y,m1,m2,L1,L2,g), [0 sim_time], y0, options);


                    % 解微分方程
                    tspan = [0 sim_time];
                    [~, y] = ode45(@(t,y) external_dp_ode(t,y,m1,m2,L1,L2,g), tspan, y0, options);

                    % 根据选择的混沌指标类型计算
                    switch chaos_type_idx
                        case 1 % 角度方差
                            var_theta1 = var(y(end-round(end/3):end, 1));
                            var_theta2 = var(y(end-round(end/3):end, 3));
                            row_chaos(j) = log(1 + var_theta1 + var_theta2);
                        case 2 % 近似李雅普诺夫指数
                            dtheta1 = diff(y(:,1));
                            dtheta2 = diff(y(:,3));
                            row_chaos(j) = log(1 + rms(dtheta1) + rms(dtheta2));
                        case 3 % 能量变化
                            E = external_pendulum_energy(y, m1, m2, L1, L2, g);
                            row_chaos(j) = std(E(end-round(end/3):end));
                    end
                end
                chaos_index(i,:) = row_chaos;
            end

            % ===== 关键修改2：安全更新图像数据 =====
            set(chaos_img, 'CData', chaos_index);
            set(ax_chaos, 'CLim', [min(chaos_index(:)) max(chaos_index(:))]);
            % ===== 结束关键修改 =====

        catch ME
            set(info_text, 'String', ['计算错误: ' ME.message]);
            return;
        end

        % 保存数据
        chaos_data.theta1_range = theta1_range;
        chaos_data.theta2_range = theta2_range;
        chaos_data.chaos_index = chaos_index;
        chaos_data.chaos_type = get(chaos_type, 'String');
        chaos_data.chaos_type_idx = chaos_type_idx;
        chaos_data.sim_time = sim_time;

        % 最终更新图像
        title(ax_chaos, '双摆混沌区域图');
        set(info_text, 'String', '混沌图生成完成！');
    end

    % 添加比对轨迹
    function add_comparison(~, ~)
        if isempty(chaos_data) || ~isfield(chaos_data, 'theta1_range')
            set(info_text, 'String', '请先生成混沌图');
            return;
        end
        
        % 提示用户选择初始角度
        answer = inputdlg({'初始θ₁ (度):', '初始θ₂ (度):'}, '输入初始角度', 1, {'90', '0'});
        if isempty(answer)
            return;
        end
        
        try
            theta1_deg = str2double(answer{1});
            theta2_deg = str2double(answer{2});
            
            % 检查角度是否在范围内
            if abs(theta1_deg) > 180 || abs(theta2_deg) > 180
                error('角度必须在-180到180度之间');
            end
            
            % 模拟双摆轨迹
            sim_time = chaos_data.sim_time;
            tspan = linspace(0, sim_time, 1000); % 固定点数以获得平滑轨迹
            options = odeset('RelTol', 1e-8, 'AbsTol', 1e-10);
            
            theta1_0 = deg2rad(theta1_deg);
            theta2_0 = deg2rad(theta2_deg);
            y0 = [theta1_0; 0; theta2_0; 0];
            
            [t, y] = ode45(@(t,y) dp_ode(t,y,params), tspan, y0, options);
            
            % 限制角度在[-π,π]
            y(:,1) = mod(y(:,1)+pi, 2*pi)-pi;
            y(:,3) = mod(y(:,3)+pi, 2*pi)-pi;
            
            % 存储比对轨迹
            trace_data = struct(...
                'theta1', y(:,1), ...
                'theta2', y(:,3), ...
                't', t, ...
                'init_theta1', theta1_deg, ...
                'init_theta2', theta2_deg, ...
                'color', rand(1,3));
            
            comparison_traces{end+1} = trace_data;
            
            % 在混沌图上标记初始点
            if ishandle(chaos_img)
                hold(ax_chaos, 'on');
                plot(ax_chaos, theta1_deg, theta2_deg, 'wo', 'MarkerSize', 8, 'LineWidth', 1.5);
                text(ax_chaos, theta1_deg, theta2_deg, num2str(length(comparison_traces)), ...
                     'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                hold(ax_chaos, 'off');
            end
            
            % 绘制比对轨迹
            cla(ax_trace);
            for k = 1:length(comparison_traces)
                trace = comparison_traces{k};
                plot(ax_trace, trace.theta1, trace.theta2, '-', ...
                    'Color', trace.color, 'LineWidth', 1.5);
                hold(ax_trace, 'on');
                plot(ax_trace, trace.theta1(1), trace.theta2(1), 'o', ...
                    'Color', trace.color, 'MarkerFaceColor', trace.color);
                text(ax_trace, trace.theta1(1), trace.theta2(1), num2str(k), ...
                     'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end
            hold(ax_trace, 'off');
            
            xlim(ax_trace, [-pi pi]);
            ylim(ax_trace, [-pi pi]);
            xticks(ax_trace, -pi:pi/2:pi);
            yticks(ax_trace, -pi:pi/2:pi);
            xticklabels(ax_trace, {'-π','-π/2','0','π/2','π'});
            yticklabels(ax_trace, {'-π','-π/2','0','π/2','π'});
            grid(ax_trace, 'on');
            
            set(info_text, 'String', sprintf('已添加轨迹 %d: θ₁=%.1f°, θ₂=%.1f°', ...
                length(comparison_traces), theta1_deg, theta2_deg));
            
        catch ME
            set(info_text, 'String', ['错误: ' ME.message]);
        end
    end

    % 保存图像
    function save_image(~, ~)
        if isempty(chaos_data) || ~isfield(chaos_data, 'theta1_range')
            set(info_text, 'String', '没有可保存的图像数据');
            return;
        end
        
        [filename, pathname] = uiputfile({'*.png'; '*.jpg'; '*.pdf'; '*.fig'}, '保存图像');
        if isequal(filename, 0) || isequal(pathname, 0)
            return;
        end
        
        try
            % 创建高质量图像
            f = figure('Visible', 'off', 'Position', [100, 100, 1000, 800]);
            
            % 复制混沌图
            ax1 = subplot(2,1,1);
            imagesc(chaos_data.theta1_range, chaos_data.theta2_range, chaos_data.chaos_index);
            axis xy; colorbar;
            title(sprintf('双摆混沌区域图 (%s)', chaos_data.chaos_type{chaos_data.chaos_type_idx}));
            xlabel('初始θ₁ (度)'); ylabel('初始θ₂ (度)');
            colormap('jet');
            
            % 标记比对点
            if ~isempty(comparison_traces)
                hold on;
                for k = 1:length(comparison_traces)
                    trace = comparison_traces{k};
                    plot(trace.init_theta1, trace.init_theta2, 'wo', 'MarkerSize', 8, 'LineWidth', 1.5);
                    text(trace.init_theta1, trace.init_theta2, num2str(k), ...
                         'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                end
                hold off;
            end
            
            % 复制轨迹图
            ax2 = subplot(2,1,2);
            for k = 1:length(comparison_traces)
                trace = comparison_traces{k};
                plot(trace.theta1, trace.theta2, '-', 'Color', trace.color, 'LineWidth', 1.5);
                hold on;
                plot(trace.theta1(1), trace.theta2(1), 'o', 'Color', trace.color, 'MarkerFaceColor', trace.color);
                text(trace.theta1(1), trace.theta2(1), num2str(k), ...
                     'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end
            hold off;
            grid on;
            title('比对轨迹');
            xlabel('θ₁ (rad)'); ylabel('θ₂ (rad)');
            xlim([-pi pi]); ylim([-pi pi]);
            xticks(-pi:pi/2:pi); yticks(-pi:pi/2:pi);
            xticklabels({'-π','-π/2','0','π/2','π'});
            yticklabels({'-π','-π/2','0','π/2','π'});
            
            % 保存图像
            saveas(f, fullfile(pathname, filename));
            close(f);
            set(info_text, 'String', '图像保存成功！');
        catch
            set(info_text, 'String', '图像保存失败');
        end
    end

    % 新增：轨迹选择模式切换
    function toggle_trace_selection(~, ~)
        trace_selection_mode = ~trace_selection_mode;
        btn = findobj(fig, 'Tag', 'trace_selector_btn');
        
        if trace_selection_mode
            set(btn, 'String', '退出点选模式', 'BackgroundColor', [0.8 0.3 0.3]);
            set(fig, 'WindowButtonDownFcn', @select_trace_point);
            set(info_text, 'String', '点选模式已激活：点击混沌图上任意位置生成轨迹');
        else
            set(btn, 'String', '寻找轨迹', 'BackgroundColor', [0.8 0.8 0.8]);
            set(fig, 'WindowButtonDownFcn', '');
            set(info_text, 'String', '点选模式已关闭');
            set(coord_display, 'String', '当前坐标: 未选择');
        end
        drawnow;
    end

    % 新增：点选生成轨迹
    function select_trace_point(~, ~)
        if ~trace_selection_mode, return; end
        
        % 获取点击坐标
        cp = get(ax_chaos, 'CurrentPoint');
        x = cp(1,1); y = cp(1,2);
        
        % 检查是否在有效范围内
        xlims = get(ax_chaos, 'XLim');
        ylims = get(ax_chaos, 'YLim');
        
        if x < xlims(1) || x > xlims(2) || y < ylims(1) || y > ylims(2)
            set(info_text, 'String', '点击位置超出范围，请点击图像区域内');
            return;
        end
        
        % 更新坐标显示
        current_coords = [x, y];
        set(coord_display, 'String', sprintf('当前坐标: θ₁=%.2f°, θ₂=%.2f°', x, y));
        
        % 自动生成轨迹
        add_comparison_auto(x, y);
    end

    % 新增：自动添加比对轨迹
    function add_comparison_auto(theta1_deg, theta2_deg)
        try
            % 获取当前m1值
            m1 = max(1, min(30, str2double(get(mt1_edit, 'String'))));
            params.m1 = m1;  % 更新params结构体
            
            % 模拟双摆轨迹
            sim_time = chaos_data.sim_time;
            tspan = linspace(0, sim_time, 1000);
            options = odeset('RelTol', 1e-8);
            
            theta1_0 = deg2rad(theta1_deg);
            theta2_0 = deg2rad(theta2_deg);
            y0 = [theta1_0; 0; theta2_0; 0];
            
            [t, y] = ode45(@(t,y) dp_ode(t,y,params), tspan, y0, options);
            
            % 限制角度在[-π,π]
            y(:,1) = mod(y(:,1)+pi, 2*pi)-pi;
            y(:,3) = mod(y(:,3)+pi, 2*pi)-pi;
            
            % 存储比对轨迹
            trace_data = struct(...
                'theta1', y(:,1), ...
                'theta2', y(:,3), ...
                't', t, ...
                'init_theta1', theta1_deg, ...
                'init_theta2', theta2_deg, ...
                'color', [rand(1,3)*0.5 + 0.5]); % 生成柔和的随机颜色
            
            comparison_traces{end+1} = trace_data;
            
            % 在混沌图上标记初始点
            if ishandle(chaos_img)
                hold(ax_chaos, 'on');
                plot(ax_chaos, theta1_deg, theta2_deg, 'wo', 'MarkerSize', 8, 'LineWidth', 1.5);
                text(ax_chaos, theta1_deg, theta2_deg, num2str(length(comparison_traces)), ...
                     'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                hold(ax_chaos, 'off');
            end
            
            % 绘制比对轨迹
            update_trace_plot();
            
            set(info_text, 'String', sprintf('已添加轨迹 %d: θ₁=%.2f°, θ₂=%.2f°', ...
                length(comparison_traces), theta1_deg, theta2_deg));
            
        catch ME
            set(info_text, 'String', ['轨迹生成错误: ' ME.message]);
        end
    end

    % 更新轨迹图（共用函数）
    function update_trace_plot()
        cla(ax_trace);
        for k = 1:length(comparison_traces)
            trace = comparison_traces{k};
            plot(ax_trace, trace.theta1, trace.theta2, '-', ...
                'Color', trace.color, 'LineWidth', 1.5);
            hold(ax_trace, 'on');
            plot(ax_trace, trace.theta1(1), trace.theta2(1), 'o', ...
                'Color', trace.color, 'MarkerFaceColor', trace.color);
            text(ax_trace, trace.theta1(1), trace.theta2(1), num2str(k), ...
                 'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        end
        hold(ax_trace, 'off');
        
        xlim(ax_trace, [-pi pi]);
        ylim(ax_trace, [-pi pi]);
        grid(ax_trace, 'on');
    end

    % 双摆微分方程 (嵌套函数版本)
    function dydt = dp_ode(~, y, p)
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

    % 全局删除
    function clearAllTraces(~, ~)
        comparison_traces = {};

        % 彻底清除左侧所有标记
        delete(findobj(ax_chaos, 'Type', 'line', 'Marker', 'o')); % 删除所有白色圆点
        delete(findobj(ax_chaos, 'Type', 'text')); % 删除所有编号文本

        % 清除右侧轨迹
        cla(ax_trace); 

        % 重置图形属性
        set(ax_trace, 'XLim', [-pi pi], 'YLim', [-pi pi]);
        grid(ax_trace, 'on');

        set(info_text, 'String', '已清除所有轨迹');
    end

    % 橡皮擦功能实现
    function toggle_eraser_mode(~, ~)
        eraser_mode = ~eraser_mode;
        btn = findobj('Tag', 'eraser_btn');

        if eraser_mode
            set(btn, 'String', '退出橡皮擦', 'BackgroundColor', [0.8 0.3 0.3]);
            set(fig, 'WindowButtonDownFcn', @erase_traces);
            set(info_text, 'String', '橡皮擦模式已激活：点击混沌图删除轨迹');
        else
            set(btn, 'String', '橡皮擦模式', 'BackgroundColor', [0.8 0.8 0.8]);
            set(fig, 'WindowButtonDownFcn', '');
            set(info_text, 'String', '橡皮擦模式已关闭');
        end
    end

    % 橡皮擦功能
    function erase_traces(~, ~)
        if ~eraser_mode, return; end

        cp = get(ax_chaos, 'CurrentPoint');
        x = cp(1,1); y = cp(1,2);
        radius = str2double(get(eraser_edit, 'String'));  % 从编辑框获取

        % 找出要删除的索引
        to_delete = false(1, length(comparison_traces));
        for k = 1:length(comparison_traces)
            trace = comparison_traces{k};
            dist = sqrt((trace.init_theta1 - x)^2 + (trace.init_theta2 - y)^2);
            to_delete(k) = dist <= radius;
        end

        if any(to_delete)
            % 先获取要保留的轨迹
            remaining_traces = comparison_traces(~to_delete);

            % 完全重绘左侧标记
            delete(findobj(ax_chaos, 'Type', 'line', 'Marker', 'o'));
            delete(findobj(ax_chaos, 'Type', 'text'));

            hold(ax_chaos, 'on');
            for k = 1:length(remaining_traces)
                trace = remaining_traces{k};
                plot(ax_chaos, trace.init_theta1, trace.init_theta2, 'wo',...
                    'MarkerSize', 8, 'LineWidth', 1.5);
                text(ax_chaos, trace.init_theta1, trace.init_theta2, num2str(k),...
                    'Color', 'w', 'HorizontalAlignment', 'center');
            end
            hold(ax_chaos, 'off');

            % 更新数据存储
            comparison_traces = remaining_traces;

            % 更新右侧轨迹图
            update_trace_plot();

            set(info_text, 'String', sprintf('已删除 %d 条轨迹', sum(to_delete)));
        end
    end

    % 同步更新函数
    function update_all_plots()
        % 先删除所有旧标记
        delete(marker_handles);
        marker_handles = gobjects(length(comparison_traces), 1);

        % 更新混沌图标记
        hold(ax_chaos, 'on');
        for k = 1:length(comparison_traces)
            trace = comparison_traces{k};
            marker_handles(k) = plot(ax_chaos, trace.init_theta1, trace.init_theta2, ...
                                   'o', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
            text(trace.init_theta1, trace.init_theta2, num2str(k), ...
                'Color', 'w', 'Parent', ax_chaos, ...
                'HorizontalAlignment', 'center');
        end
        hold(ax_chaos, 'off');

        % 更新右侧轨迹图
        cla(ax_trace);
        colors = lines(length(comparison_traces));
        for k = 1:length(comparison_traces)
            trace = comparison_traces{k};
            plot(ax_trace, trace.theta1, trace.theta2, ...
                '-', 'Color', colors(k,:), 'LineWidth', 1.5);
            hold(ax_trace, 'on');
            plot(ax_trace, trace.theta1(1), trace.theta2(1), ...
                'o', 'Color', colors(k,:), 'MarkerFaceColor', colors(k,:));
            text(ax_trace, trace.theta1(1), trace.theta2(1), num2str(k), ...
                'Color', 'k', 'HorizontalAlignment', 'center');
        end
        hold(ax_trace, 'off');
        axis(ax_trace, 'equal');
    end

    % 输入验证函数
    function validate_input(edit_h, slider_h, min_val, max_val)
        try
            val = str2double(get(edit_h, 'String'));
            if isnan(val) || val < min_val || val > max_val
                error('输入超出范围');
            end
            set(slider_h, 'Value', val);
            set(edit_h, 'String', num2str(round(val)));
        catch
            set(edit_h, 'String', num2str(get(slider_h, 'Value')));
            errordlg(sprintf('请输入%d~%d之间的数字', min_val, max_val), '输入错误');
        end
    end
 


end

