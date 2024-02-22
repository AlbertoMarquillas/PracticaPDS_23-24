function [audioOUT, audioIN] = processaudio(audioINfilename, effect, param)
    % Els paràmetres d'entrada són:
    % audioINfilename: string amb el nom del fitxer d'àudio a processar
    % effect: string que indica el tipus d'efecte ('equalizer' o 'reverb')
    % param: vector numèric amb els paràmetres de l'efecte
    
    [audioIN, originalFs] = audioread(audioINfilename);

    fs = 44100;
    f_audio = 44100;

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
            figure;
            
            subplot(2,2, 1)
            plot(f_audio, 20*log10(abs(audioIN(1:N/2+1))));
            title('Original-Freq');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            
            subplot(2,2, 2)
            plot((1:length(audioIN))/fs, audioIN);
            title('Original - Time');
            xlabel('Time (s)');
            ylabel('Amplitude');
            
            subplot(2,2, 3)
            plot(f_audio, 20*log10(abs(audioOUT(1:N/2+1))));
            title('Filtered - Freq');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
        
            subplot(2,2, 4)
            plot((1:length(audioOUT))/fs, audioOUT);
            title('Filtered - Time');
            xlabel('Time (s)');
            ylabel('Amplitude');
           
        case 'reverb'

            Tr = param(1); %Temps de reverberació
            M = param(2); %Factors de mescla

            N = Tr * fs; %muestras totales

            %implementar l’efecte de reverberació tot usant com a resposta impulsional un soroll blanc
            %Gaussià modulat amb una funció exponencial decreixent en el temps.
            
            %hr(t) = A(t)s(t)
            %A(t) = c^tu(t)

            %Calculem el numero de mostres totals que tindra la reverb

            %Calcul resposta mpulsional
            c = 10^(-60 / (10 * Tr));
            % Generar el vector de tiempo
            t = (0:N-1) / fs * Tr;
            
            % Calcular A(t)
            A = c .^ t; %envolupant exponencial decreixent de la resposta impulsional
            s = randn(size(t));  %soroll blanc i Gaussià de mitja 0 i variància 1. La funció randn.m permet generar mostres d un soroll Gaussià amb mitja 0 i variància 1.

            %Temps dereverberació 𝑇r: el temps que triga en decaure l energia de la resposta impulsional 60 dB respecte del 
            %valor inicial
            %10log10|A(Tr)| = 10og10|A(0)| - 60

            hr = A .* s; % Respuesta impulsional

            %Per aplicar l’efecte de reverberació sobre un senyal donat, usarem la funció fftfilt.m, que usa el
            % mètode basat en la FFT

            %quan apliquem l’efecte ho farem afegint al final del senyal
            %d’entrada una cadena de zeros que tingui una durada igual a la durada de la resposta impulsional menys 1. 

            %, definirem també un paràmetre d intensitat d’efecte entre 0 i 100, i denotarem com a M (de Mix), de forma que per M = 100 l’efecte sigui
            % total, mentre que si M = 50, aquest només es mescli amb el senyal original en una proporció meitat

            %primer hem de normalitzar la resposta impulsional calculada
            %dividint-la per la seva norma Euclidiana -> funcio: norm.m

            hr = hr / norm(hr);
    
            % Calcular la duración total de la respuesta impulsional en muestras
            respuesta_impulsional_muestras = length(hr);
            
            % Calcular la cantidad de ceros a agregar
            ceros_a_agregar = respuesta_impulsional_muestras - 1;

            % Generar el vector de ceros de reverberación
            ceros_reverberacion = zeros(ceros_a_agregar, 1);
            
            % Concatenar los ceros de reverberación al final del audio de entrada
            audioIN_extended = [audioIN; ceros_reverberacion];

            % Filtrar el audio de entrada con la respuesta impulsional
            audioOUT = fftfilt(hr, audioIN_extended);

            %apliquem el coeficient de mescla M de la següent forma:
            %ye = x* (1-M/100)+ y*(M/100)
            disp(size(audioIN_extended));
            disp(size(audioOUT));
            audioOUT_mix = audioIN_extended .* (1 - M/100) + audioOUT .* (M/100);

            % Construir la señal de salida sumando la señal de entrada con la reverberación deseada
            audioOUT_mix = audioIN_extended + audioOUT_mix;
            
            % Calcular la FFT de las señales de audio de entrada y salida
            audioIN_fft = fft(audioIN_extended);
            audioOUT_mix_fft = fft(audioOUT_mix);
            
            % Definir el vector de frecuencia
            f_audio = linspace(0, fs/2, length(audioIN)/2+1);
            f_audio_2 = linspace(0, fs/2, length(audioOUT_mix_fft)/2+1);
            
           
            % Plot del dominio de la frecuencia
            figure;
            subplot(2, 1, 1);
            plot(f_audio, 20*log10(abs(audioIN_fft(1:length(audioIN)/2+1))));
            title('Original - Freq');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            
            subplot(2, 1, 2);
            plot(f_audio_2, 20*log10(abs(audioOUT_mix_fft(1:length(audioOUT_mix)/2+1))));
            title('Filtered - Freq');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            
            % Plot del dominio del tiempo
            figure;
            subplot(2, 1, 1);
            plot((0:length(audioIN)-1)/fs, audioIN);
            title('Original - Time');
            xlabel('Time (s)');
            ylabel('Amplitude');
            
            subplot(2, 1, 2);
            plot((0:length(audioOUT_mix)-1)/fs, audioOUT_mix);
            title('Filtered - Time');
            xlabel('Time (s)');
            ylabel('Amplitude');

         otherwise
            error('Tipus d''efecte no vàlid. Trieu ''equalizer'' o ''reverb''.');
    
    end 



end
