function [exp_loss_min, next_sample_point] = min_around_points( objective_fn, start_pts, radius, evals )
%
% Search around a set of points, then return the best minimum found.

optim_opts = ...
    optimset('GradObj','off',...
    'Display','off', ...
    'MaxFunEvals', evals,...
    'LargeScale', 'off',...
    'Algorithm','interior-point'...
    );

[num_start_pts, D] = size(start_pts);
local_min_values = nan(num_start_pts,D);
local_min_locations = nan(num_start_pts,D);
for i = 1:num_start_pts

    cur_start_pt = start_pts(i,:);
    lower_bound = cur_start_pt - radius;
    upper_bound = cur_start_pt + radius;
    [local_min_locations(i, :), local_min_values(i)] = ...
        fmincon(objective_fn,cur_start_pt, ...
        [],[],[],[],...
        lower_bound,upper_bound,[],...
        optim_opts);
end

[exp_loss_min, min_start_i] = min(local_min_values);
next_sample_point = local_min_locations(min_start_i);
end