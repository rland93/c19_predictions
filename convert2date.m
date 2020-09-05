function [output] = convert2date(input)
   % Convert a double YYYYMMDD to datetime
   i_str = char(string(input));
   output = datetime([str2double(i_str(1:4)), str2double(i_str(4:6)),str2double(i_str(7:8))]);
end