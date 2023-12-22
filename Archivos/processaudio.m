function [audioOUT, audioIN] = processaudio(audioINfilename, effect, param)
    % Els paràmetres d'entrada són:
    % audioINfilename: string amb el nom del fitxer d'àudio a processar
    % effect: string que indica el tipus d'efecte ('equalizer' o 'reverb')
    % param: vector numèric amb els paràmetres de l'efecte
    
    [audioIN, originalFs] = audioread(audioINfilename);

    fs = 44100;

    if originalFs ~= fs
        audioIN = resample(audioIN, fs, originalFs);
    end

    load('filtersSOS.mat', 'G_BP', 'G_HP', 'G_LP', 'SOS_BP', 'SOS_HP', 'SOS_LP');

    switch effect
        case 'equalizer'

            %aplico el guany al filtre
            gainsLP = 10.^(param(1)/20);
            gainsBP = 10.^(param(2)/20);
            gainsHP = 10.^(param(3)/20);

            %aplico el guany al filtre
            SOS_LP(1, 1:3) = SOS_LP(1, 1:3) * prod(G_LP);
            SOS_BP(1, 1:3) = SOS_BP(1, 1:3) * prod(G_BP);
            SOS_HP(1, 1:3) = SOS_HP(1, 1:3) * prod(G_HP);

            %calculo l'output de l'audio per cada filtre
            audioOUT_LP = sosfilt(SOS_LP, audioIN);
            audioOUT_BP = sosfilt(SOS_BP, audioIN);
            audioOUT_HP = sosfilt(SOS_HP, audioIN);

            %junto els filtres per una sortida conjunta
            audioOUT = audioOUT_LP + audioOUT_BP + audioOUT_HP;
          
            N = 2048; 
            x = [1; zeros(N-1, 1)];    
            [min_gain, max_gain] = bounds(param);

            %m'asseguro dels zeros i calculo rsposta impulsional
            h_LP = sosfilt(SOS_LP, x);
            h_BP = sosfilt(SOS_BP, x);
            h_HP = sosfilt(SOS_HP, x);
            
            h_LP = h_LP * gainsLP;
            h_BP = h_BP * gainsBP;
            h_HP = h_HP * gainsHP;

            %trec la frequencia
            [H_LP, f_LP] = freqz(h_LP, 1, N, fs);
            [H_BP, f_BP] = freqz(h_BP, 1, N, fs);
            [H_HP, f_HP] = freqz(h_HP, 1, N, fs);

            %calculo el global
            H_combined = H_LP + H_BP + H_HP ;
            
            %trec la fase
            phase = phasez(H_LP, 1) + phasez(H_BP,1) + phasez(H_HP,1);
            %plots
            figure;
            
            subplot(3, 1, 1);
            semilogx(f_LP, 10*log10(abs(H_LP)), 'b'); 
            hold on;
            semilogx(f_BP, 10*log10(abs(H_BP)), 'r'); 
            semilogx(f_HP, 10*log10(abs(H_HP)), 'y');
            hold off;
            title('Individual Filters');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            xlim([0 23000]);
            ylim([min_gain-15 max_gain+15]);
            legend('LowPass filter', 'BandPass filter', 'HighPass filter');
            grid on;
            
            subplot(3, 1, 2);
            semilogx(f_LP, 10*log10(abs(H_combined)));
            title('Custom Filter Response');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            xlim([0 23000]);
            ylim([min_gain-15 max_gain+15]);
            grid on;
            
            subplot(3, 1, 3);   
            semilogx(phase);
            title('Custom Filter Phase');
            xlabel('Frequency (Hz)');
            ylabel('Phase (degrees)');
            xlim([0 23000]);
            ylim([-25 0]);
            grid on;

           
        case 'reverb'
            Tr = param(1); 
            M = param(2);

            10 * log10 (abs(A(Tr)))

            randn()
            senyalConvolucionada = fftfilt() %genera a la sortida un senyal de la mateixa durada que l entrada

            senyalZeros = zeros();
            senyalOutput = [senyalConvolucionada senyalZeros]

            H = H/norm(H); %normalitzar la resposta impulsional
            ye = x*(1-M/100) + y*(M/100);

         otherwise
            error('Tipus d''efecte no vàlid. Trieu ''equalizer'' o ''reverb''.');
    
    end

    figure;
    
    subplot(2,2, 1)
    plot(f_audio, 20*log10(abs(audioIN_fft(1:N/2+1))));
    title('Original-Freq');
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    
    subplot(2,2, 2)
    plot((1:length(audioIN))/fs, audioIN);
    title('Original - Time');
    xlabel('Time (s)');
    ylabel('Amplitude');
    
    subplot(2,2, 3)
    plot(f_audio, 20*log10(abs(audioOUT_fft(1:N/2+1))));
    title('Filtered - Freq');
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');

    subplot(2,2, 4)
    plot((1:length(audioOUT))/fs, audioOUT);
    title('Filtered - Time');
    xlabel('Time (s)');
    ylabel('Amplitude');

end
