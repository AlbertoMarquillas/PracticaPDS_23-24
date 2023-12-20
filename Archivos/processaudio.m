function [audioOUT, audioIN] = processaudio(audioINfilename, effect, param)
    % Els paràmetres d'entrada són:
    % audioINfilename: string amb el nom del fitxer d'àudio a processar
    % effect: string que indica el tipus d'efecte ('equalizer' o 'reverb')
    % param: vector numèric amb els paràmetres de l'efecte
    
    fs = 44100;  % Frecuencia de muestreo

    [audioIN, originalFs] = audioread(audioINfilename);

    % Resample the input audio to 44100 Hz if the original frequency is different
    if originalFs ~= fs
        audioIN = resample(audioIN, fs, originalFs);
    end

    load('filtersSOS.mat');
    
    N = 2048; 
    x = [1; zeros(N-1, 1)];    

    h_LP = sosfilt(SOS_LP, x);
    h_BP = sosfilt(SOS_BP, x);
    h_HP = sosfilt(SOS_HP, x);
    
    [H_LP, f] = freqz(h_LP, 1, N, fs);
    [H_BP, f] = freqz(h_BP, 1, N, fs);
    [H_HP, f] = freqz(h_HP, 1, N, fs);

    % Apply the selected effect
    switch effect
        case 'equalizer'
            linearGains = 10.^(param / 20);  

            SOS_LP(1, 1:3) = SOS_LP(1, 1:3) * linearGains(1);
            SOS_BP(1, 1:3) = SOS_BP(1, 1:3) * linearGains(2);
            SOS_HP(1, 1:3) = SOS_HP(1, 1:3) * linearGains(3);

            audioOUT_LP = sosfilt(SOS_LP, audioIN);
            audioOUT_BP = sosfilt(SOS_BP, audioIN);
            audioOUT_HP = sosfilt(SOS_HP, audioIN);

            figure;
            semilogx(f, 20*log10(abs(H_LP)), 'b'); 
            hold on;
            semilogx(f, 20*log10(abs(H_BP)), 'r'); 
            semilogx(f, 20*log10(abs(H_HP)), 'g');
            hold off;
            xlabel('Frequency (Hz)');
            ylabel('Gain (dB)');
            title('Frequency Response of the Filters');
            legend('Low Pass', 'Band Pass', 'High Pass');
            grid on;

            audioOUT = audioOUT_LP + audioOUT_BP + audioOUT_HP;

            soundsc(audioOUT, fs);
        case 'reverb'
            % Codi per aplicar l'efecte de reverb amb els paràmetres proporcionats
            % ...
            % audioOUT = ...
        
        case 'none'
            soundsc(audioIN, fs);

        otherwise
            error('Tipus d''efecte no vàlid. Trieu ''equalizer'' o ''reverb''.');
    end

    % Reproduir l'àudio de sortida
    soundsc(audioOUT, fs);

end
