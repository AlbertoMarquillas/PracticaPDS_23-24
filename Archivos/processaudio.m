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

    % Apply the selected effect
    switch effect
        case 'equalizer'
            SOS_matrix(1,1:3) = SOS(1,1:3)*prod(G);
 
            % Aplicar el filtro combinado a la señal de entrada (por ejemplo, 'audioIN')
            audioOUT = sosfilt(SOS_matrix, audioIN);
            
            % Reproducir la señal de salida
            soundsc(audioOUT, fs);
        case 'reverb'
            % Codi per aplicar l'efecte de reverb amb els paràmetres proporcionats
            % ...
            % audioOUT = ...

        otherwise
            error('Tipus d''efecte no vàlid. Trieu ''equalizer'' o ''reverb''.');
    end

    % Reproduir l'àudio de sortida
    soundsc(audioOUT, fs);

end
