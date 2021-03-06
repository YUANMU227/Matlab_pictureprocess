function jpegcodes = msg_hide(pic,msg,method)
%信息隐藏函数
%返回值y为隐藏后的图像JPEG编码
%输入pic为图像
%msg为待隐藏信息（字符串），若过长会被裁剪
%method代表隐藏方法，
%1为替换所有DCT系数低位
%2为替换部分
%3为替换每个图像块最后非零系数

load('JpegCoeff.mat');
if(~ischar(msg) & ~isstring(msg))
    error('Input msg must be a char array or a string!');
end
msg = char(msg);
[H,W]=size(pic);
result = DCT_result(pic);           %得到DCT系数矩阵

%---------------------嵌入信息-----------------------
[r,c]=size(result);
msg_array = char2bin(msg,method);   %获得需要表示的信息数列

switch method
    case 1
        result = result(:);         %result变为列向量
        result = result - mod(result,2);    %使每个DCT系数的最后一位都为0
        if(length(msg_array) < length(result))
            msg_array(end+1:end+length(result)-length(msg_array))=0; %使msg_array与result等长
        end
        result = result + msg_array(1:length(result));   %修改每一位DCT系数的最低位
        result = reshape(result,r,c);
    case 2
        result = result(:);         %result变为列向量
        l = length(msg_array);
        if(l > length(result))
            l = length(result);
        end
        
        result(1:l) = result(1:l) - mod(result(1:l),2);    %使每个DCT系数的最后一位都为0
        result(1:l) = msg_array(1:l)+result(1:l);   %修改部分
        result = reshape(result,r,c);
    case 3
        l = size(result,2);     %图像的块数
        if(l > length(msg_array))
            l = length(msg_array);
        end
        for i = 1:l
            column = result(:,i);
            index = length(column); %最后一个非0系数的下标
            find = 0;
            while(~find)
                if(column(index)~=0)
                    find=1;
                else
                    index = index-1;
                end
            end
            %由此找到最后一个非零系数index
            if(index==length(column))
                column(index) = msg_array(i);
            else
                column(index+1)=msg_array(i);
            end
            %将信息写入
            result(:,i)=column;
        end
                
    otherwise
        error(strcat('No such method called',method+'0'));
end


%------------综上得到信息隐藏后的矩阵result,以下进行JPEG编码------------------------
DC = result(1,:);           %第一行即为DC系数
DC_code = DC_coeff(DC);     %DC码
AC_code = '';               %AC码
for i = 1:c            %逐块翻译AC码
    AC_code = strcat(AC_code,AC_coeff(result(2:end,i)));
end
jpegcodes = struct('DC_code',{DC_code},'AC_code',AC_code,'H',H,'W',W);

%--------------------------对图像进行评价-------------------------
y = JPEG_decoder(jpegcodes);      %解码，得到待隐藏信息图片
%-----------------------计算图片质量，压缩比-----------------------------
[PSNR,PSNR0,ratio,ratioO] = calculate_pic(pic,jpegcodes,y);

sprintf('原压缩比为:%f,加密后压缩比为:%f,\r\n 原图像经过jpeg编码后:PSNR=%f,加密后的图像与原图像对比:PSNR=%f',ratioO,ratio,PSNR0,PSNR)%打印信息


end

function msg_array = char2bin(msg,method)
%返回字符串对应ascii码的二进制码流
%方法1,2均返回正常的二进制码流（末尾加一个全0位）
%方法3将二进制码流中的0全部替换为-1
msg = dec2bin(abs(msg))';   %每列代表一个ascii码
msg = [zeros(8-size(msg,1),size(msg,2))+'0';msg];
msg = msg(:);           %将全部二进制码合成一个列向量
msg_array = abs(msg-'0');
msg_array(end+1:end+8) = zeros(8,1); %最后位补0
if(method == 3)
    for i = 1:length(msg_array)
        if(msg_array(i)==0)
            msg_array(i)=-1;
        end
    end
end

if(method ~= 1 & method~=2 &method~=3)
    error('no such method');
end

end

function [PSNR,PSNRO,ratio,ratioO] = calculate_pic(pic,jpegcodes,y)
%以下计算压缩比，图像质量
[r,c] = size(pic);
pic_size = r*c;             %计算原始图像字节数
code_length = length(jpegcodes.DC_code)+length(jpegcodes.AC_code);%计算码流长度
ratio = pic_size*8/code_length;    %字节数乘8后除于码流长度即为压缩比
MSE = 1/r/c*sum(sum((double(y)-double(pic)).^2));
PSNR = 10*log10(255^2/MSE);              %计算图像质量
original_jpeg = JPEG_encoder(pic);
code_length = length(original_jpeg.DC_code)+length(original_jpeg.AC_code);%计算码流长度
ratioO = pic_size*8/code_length ;   %原图像压缩比
%计算正常情况PSNR
pic2 = JPEG_decoder(original_jpeg);
MSE = 1/r/c*sum(sum((double(pic2)-double(pic)).^2));
PSNRO = 10*log10(255^2/MSE);              %计算图像质量

end
