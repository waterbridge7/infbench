function c = colorbrew( i, flag, N )
%
% Nice colors taken from 
% http://colorbrewer2.org/
%
% David Duvenaud
% March 2012

if nargin <2
    flag = 'qual';
end

switch flag
    case 'qual'
        c_array(1, :) = [ 228, 26, 28 ];   % red
        c_array(2, :) = [ 55, 126, 184 ];  % blue
        c_array(3, :) = [ 255, 127, 0 ];   % orange
        c_array(4, :) = [ 77, 175, 74 ];   % green
        c_array(5, :) = [ 152, 78, 163 ];  % purple
        c_array(6, :) = [ 153, 153, 153]; % grey
        c_array(7, :) = [ 166, 86, 40 ];   % brown
        c_array(8, :) = [ 247, 129, 191 ]; % pink
        c_array(9, :) = [ 255, 255, 51 ];  % yellow
        
        c = c_array( mod(i - 1, 10) + 1, : ) ./ 255;
        
    case 'seq'
        
        c_array_d = [254, 196, 79;
        254, 153, 41;
        236, 112, 20;
        204, 76, 2;
        153, 52, 4;
        102, 37, 6];
    
        d = size(c_array_d, 1);
    
        c_array = interp1((1:d)', c_array_d, linspace(1, d, N)');
        
        c = c_array( i, : ) ./ 255;
    
    case 'seq1'
% 
        c_array_d = [255, 255, 217;
            237, 248, 217;
            199, 233, 180;
        127, 205, 187;
        65, 182, 196;
        29, 145, 192;
        34, 94, 168;
        37, 52, 148;
        8, 29, 88];
    
        d = size(c_array_d, 1);

    
        c_array = interp1((1:d)', c_array_d, linspace(1, d, N)');
        
        c = c_array( i, : ) ./ 255;
        
    case 'div'
        
        c_array_d = [158, 1, 66;
        213, 62, 79;
        244, 109, 67;
        253, 174, 97;
%         254, 224, 139;
%         255, 255, 191;
%         230, 245, 152;
        171, 221, 164;
        102, 194, 165;
        50, 136, 189;
        94, 79, 162];
    
        d = size(c_array_d, 1);

    
        c_array = interp1((1:d)', c_array_d, linspace(1, d, N)');
        
        c = c_array( i, : ) ./ 255;
        
case 'divb'
        
        c_array_d = [158, 1, 66;
        213, 62, 79;
        244, 109, 67;
        253, 174, 97;
        254, 224, 139;
        255, 255, 191;
        230, 245, 152;
        171, 221, 164;
        102, 194, 165;
        50, 136, 189;
        94, 79, 162];
    
        d = size(c_array_d, 1);

    
        c_array = interp1((1:d)', c_array_d, linspace(1, d, N)');
        
        c = c_array( i, : ) ./ 255;
        
end


end
