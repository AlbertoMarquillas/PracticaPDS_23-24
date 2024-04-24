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

    load('filtersSOS.mat','G_BP','G_LP','G_HP', 'SOS_LP', 'SOS_BP', 'SOS_HP');

    switch effect
        case 'equalizer'
            
            n = 2048;
            N = 1000000;
            x = [1; zeros(N-1, 1)];

            %aplico el guany al filtre
            SOS_LP(1, 1:3) = SOS_LP(1, 1:3) * db2mag(param(1)) * prod(G_LP);
            SOS_BP(1, 1:3) = SOS_BP(1, 1:3) * db2mag(param(2)) * prod(G_BP);
            SOS_HP(1, 1:3) = SOS_HP(1, 1:3) * db2mag(param(3)) * prod(G_HP);
    
            %m'asseguro dels zeros i calculo rsposta impulsional
            h_LP = sosfilt(SOS_LP, x);
            h_BP = sosfilt(SOS_BP, x);
            h_HP = sosfilt(SOS_HP, x);
            
            %trec la frequencia
            [H_LP, f_LP] = freqz(h_LP, 1, n, fs);
            [H_BP, f_BP] = freqz(h_BP, 1, n, fs);
            [H_HP, f_HP] = freqz(h_HP, 1, n, fs);
            [H_total, f_audioIN] = freqz(audioIN,1,length(audioIN),fs);

            %calculo l'output de l'audio per cada filtre
            audioOUT_LP = sosfilt(SOS_LP, audioIN);
            audioOUT_BP = sosfilt(SOS_BP, audioIN);
            audioOUT_HP = sosfilt(SOS_HP, audioIN);

            %calculo el global
            audioOUT = audioOUT_LP + audioOUT_BP + audioOUT_HP;
            [H_audioOut,f_audioOut] = freqz(audioOUT,1,length(audioOUT),fs);

            %Calculem la H total
            h = h_LP + h_BP + h_HP;
            [H,f] = freqz(h,1,n,fs);

            %plots
            figure
            subplot(3,1,1);
            semilogx(f_LP, 20*log10(abs(H_LP)));
            title('Individual Filters');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            ylim ([-40,max(param)+10]);
            hold on
            semilogx(f_BP, 20*log10(abs(H_BP)));
            semilogx(f_HP, 20*log10(abs(H_HP)));
            legend('LowPass filter', 'BandPass filter', 'HighPass filter');
            hold off;
            grid on;
            
            subplot(3,1,2);
            semilogx(f, 20*log10(abs(H)));
            title('Custom Filter Response');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            ylim ([-40,max(param)+20]);
            grid on;

            subplot(3, 1, 3);
            plot(f, unwrap(angle(H)));
            title("Custom Filter Fase");
            xlabel("Frequency (Hz)");
            ylabel("Phase (degrees)");
            xlim([0, 10^4]);
            grid on


            figure;
            subplot(2,2,1);
            semilogx(f_audioIN, 20*log10(abs(H_total)));
            title("Original-Freq.");
            xlabel("Frequency (Hz)");
            ylabel("Magnitude (dB)");
            xlim([20, fs/2]);
            ylim padded;
            grid on
            subplot(2,2,3)
            semilogx(f_audioOut, 20*log10(abs(H_audioOut)));
            title("Filtered-Freq.");
            xlabel("Frequency (Hz)");
            ylabel("Magnitude (dB)");
            xlim([20, fs/2]);
            ylim padded;
            grid on
            subplot(2,2,2); 
            t_audioIN = (0:length(audioIN)-1) / fs;
            plot(t_audioIN,audioIN);
            title("Original-Time");
            xlabel("time");
            ylabel("amplitude");
            xlim tight;
            ylim padded;
            grid on
            subplot(2,2,4);
            t_audioOUT = (0:length(audioOUT)-1) / fs;
            plot(t_audioOUT,audioOUT);
            title("Filtered-Time");
            xlabel("time");
            ylabel("amplitude");
            xlim tight;
            ylim padded;
            grid on

            
            soundsc(audioOUT);  

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
            c = 10^(-6/Tr);
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
            subplot(2, 2, 1);
            semilogx(f_audio, 20*log10(abs(audioIN_fft(1:length(audioIN)/2+1))));
            title('Original - Freq');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            xlim([0 100000]);

            subplot(2, 2, 3);
            semilogx(f_audio_2, 20*log10(abs(audioOUT_mix_fft(1:length(audioOUT_mix)/2+1))));
            title('Filtered - Freq');
            xlabel('Frequency (Hz)');
            ylabel('Magnitude (dB)');
            xlim([0 10000]);

            subplot(2, 2, 2);
            plot((0:length(audioIN)-1)/fs, audioIN);
            title('Original - Time');
            xlabel('Time (s)');
            ylabel('Amplitude');
            
            subplot(2, 2, 4);
            plot((0:length(audioOUT_mix)-1)/fs, audioOUT_mix);
            title('Filtered - Time');
            xlabel('Time (s)');
            ylabel('Amplitude');

            soundsc(audioOUT_mix);

         otherwise
            error('Tipus d''efecte no vàlid. Trieu ''equalizer'' o ''reverb''.');
    
    end 


end
