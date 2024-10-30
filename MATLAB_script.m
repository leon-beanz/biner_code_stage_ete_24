%% MATLAB script for behavioral training setups: Go No-Go task %%
%% NO parallel computting - 1 board at the time %%

%Written by Eric Martineau; Adapted by Alessandra Ciancone and Léon Biner

%% Initialize all training setups in parallel if necessary  
%This section will check if the intialization has already been done. 
%If no,ensure that the script is at its the begining on the Arduino boards (press
%reset button if necessary). The script will prompt you to input the COM
%port number and the animal info for each setup.
%If yes, this section will simply reprompt you to input the animal infos

if exist('Initialization','var') == 1 %check if Initialization already done %%check if initialization variable exist in workspace or search path
    if Initialization == 'y' %if yes
        disp('Initialization already done');
        
        %prompt the number of boards to monitor (in this case will always be one)
        prompt = {'Number of boards to monitor'};
        dlgtitle = '';
        dims = [1 50];
        definput = {'1'};
        answer = inputdlg(prompt,dlgtitle,dims,definput);
    
        numBoard = str2double(answer{1}); % in this case will always be 1

        %prompt for trial info
        prompt = {'COM PORT #?','AnimalID', 'Genotype', 'task#'}; % Prompt user for COM_PORT number and animal id %
        t = num2str(numBoard);
        dlgtitle = ['Setup #' t];
        dims = [1 50];
        definput = {'COM4','B7#2', 'SRGAP','01'};
        answer = inputdlg(prompt,dlgtitle,dims,definput);
        portID = answer{1};
        animalID= answer{2};
        genotype= answer{3};
        taskNum= answer{4};

    else
        error('ERROR1. Initialization exists but unequal to y. Clear all, reset boards and restart.');
    end
else
  error('ERROR2. Initialization does not exists. Clear all, reset boards and restart.');
end


Seq = randperm(MaxTrial); %randomizes trial sequence for each setup
%I wrote this here below and before the END_LEON comment
       three_in_row = true;
       while three_in_row == true
           three_in_row = false;
           real_in_row = 0;
           sham_in_row = 0;
           Seq = randperm(MaxTrial); %randomizes trial sequence for each setup
           for i = 1:length(Seq)
               element = Seq(i);
               if element <= 12
                   real_in_row = real_in_row + 1;
                   sham_in_row = 0;
               else
                   sham_in_row = sham_in_row + 1;
                   real_in_row = 0;
               end
               if real_in_row >= 3 || sham_in_row >= 3
                   three_in_row = true;
                   break;
               end
           end
       end
   %END_LEON


Initialization = 'y';

%% -----Creation of Trial Log------- %%
 Trial_log= struct('Type',cell(1,MaxTrial),'Start',cell(1,MaxTrial),'StimTime',cell(1,MaxTrial),'End',cell(1,MaxTrial),'Response',cell(1,MaxTrial),'LickTime',cell(1,MaxTrial),'Result',cell(1,MaxTrial),'rewDelay',cell(1,MaxTrial),'rewTime',cell(1,MaxTrial));
    %Create a structure "Trial" containing all trial infos (timings,
    %responses etc.).
  for TrialNum = 1:MaxTrial  
        disp(strcat('Running Trial #',num2str(TrialNum)));
    

       while startsWith(Serial_Input,"Type?") ~= 1
            Serial_Input = readline(arduino); 
       end
               

        % send associated trial number
        q = (Seq(1,TrialNum)); %% seq(row,column)
        write(arduino,q,'int8');
        %pause(5);

        %confirm trasmitted r
        while startsWith(Serial_Input,"Available :") ~= 1
            Serial_Input = readline(arduino); 
        end
        r = sscanf(Serial_Input,'Available :%d');


        %Wait for reply from arduino
        while startsWith(Serial_Input,"Trial type") ~= 1
            i = arduino.NumBytesAvailable;
            while i ==0
                i = arduino.NumBytesAvailable;
            end
            Serial_Input = readline(arduino);
        end

        %Extract trial type and log
        t = sscanf(Serial_Input,'Trial type:%d');
        switch t
            case 1
                Trial_log(TrialNum).Type = "Real";
                disp('Real trial');
            case 2
                Trial_log(TrialNum).Type = "Sham";
                disp('Sham trial');
            otherwise
                Trial_log(TrialNum).Type = "Error";
        end
    

        %Wait for rdy and signal arduino to go
        while startsWith(Serial_Input,"rdy?") ~= 1 
            Serial_Input = readline(arduino);
        end
        write(arduino,'y','char');
        

    %% ----------Auditory Stimulation------------ %%

%MATLAB script to listen for commands from Arduino to play sound files

%Read and process data 
while startsWith(Serial_Input,"Trial start") ~= 1 
    %Read command from serial port
    Serial_Input = readline(arduino);
end
    %Check the command recieved from Arduino
    Serial_Input = readline(arduino);
    if startsWith(Serial_Input,"play_10khz") == 1
        %Play sound file 
        [y,Fs]= audioread('pureTone_10khz.wav');%load sound file
        sound(y,Fs); % play sound
       
    elseif startsWith(Serial_Input,"play_5khz") == 1
        %Play sound file 
        [y,Fs]= audioread('pureTone_5khz.wav');%load sound file
        sound(y,Fs); % play sound
    end 
 

        %wait for arduino to send trial timings
        i = arduino.NumBytesAvailable;
        while i ==0
            i = arduino.NumBytesAvailable;
        end
    
%% ----------Data extraction%------------ %%


        %read and log trial timings
        Serial_Input = readline(arduino);
        Trial_log(TrialNum).Start = sscanf(Serial_Input,'Trial Start:%d');
        Serial_Input = readline(arduino);
        Trial_log(TrialNum).StimTime = sscanf(Serial_Input,'Stim Time:%d');
        Serial_Input = readline(arduino);
        Trial_log(TrialNum).End = sscanf(Serial_Input,'Trial End:%d');
        Serial_Input = readline(arduino);
        Trial_log(TrialNum).Response = sscanf(Serial_Input,'Response:%s');
        Serial_Input = readline(arduino);
        if(startsWith(Serial_Input,"LickTime")) == 1
            Trial_log(TrialNum).LickTime = sscanf(Serial_Input,'LickTime:%d');
            Serial_Input = readline(arduino);
        else
            Trial_log(TrialNum).LickTime = 'NaN';
        end
        Trial_log(TrialNum).Result = sscanf(Serial_Input,'Result:%s');
        Serial_Input = readline(arduino);
        if(startsWith(Serial_Input,"rewDelay")) == 1
            Trial_log(TrialNum).rewDelay = sscanf(Serial_Input,'rewDelay:%d');
            Serial_Input = readline(arduino);
            Trial_log(TrialNum).rewTime = sscanf(Serial_Input,'rewTime:%d');
        else
            Trial_log(TrialNum).rewDelay = 'NaN';
            Trial_log(TrialNum).rewTime = 'NaN';
        end
    end

    i = arduino.NumBytesAvailable; %empty serial com buffer at the end of all trials
        while i ~=0
            Serial_Input = readline(arduino);
            i = arduino.NumBytesAvailable;
        end


%% Extraction of composite variables to the client - Parallel Computing NOT USED %%
% see GoNoGo_ALE_Sim_ParModified.m %

%% ------Save trial file and create expLog for each animal----- %%
%%for i = 1:numBoard
    filename = strcat(string(datetime("today")),'_',animalID,'_',genotype,'_task',taskNum,'.mat');
    Trial = Trial_log;
    save(filename, 'Trial');
%     save(XX, 'Trial'); %% just saving the trail?

    logname = strcat(filename,"_log.txt");
    ExpLog = fopen(logname,'w');

    fprintf(ExpLog,'%9s %12s\r\n','Animal ID:',animalID);
    fprintf(ExpLog,'%9s %12s\r\n','Genotype:',genotype);
    fprintf(ExpLog,'%9s %12s\r\n','Stack #:',taskNum);
    fprintf(ExpLog,'%9s %12s\r\n','Date:',datetime("today"));
    fprintf(ExpLog,'%9s %12s\r\n\r\n','Time:',datetime('now','Format','HH:mm'));
    fprintf(ExpLog,'%9s %12s\r\n','Protocol:',ProtocolName);
    fprintf(ExpLog,'%24s %6d\r\n','Stimulus duration (ms)',stimDur);
    fprintf(ExpLog,'%24s %6d\r\n','PreStim delay (ms)',preStim);
    fprintf(ExpLog,'%24s %6d\r\n','PostStim delay (ms)',postStim);
    fprintf(ExpLog,'%24s %6d\r\n','iti (ms)',iti{i});
    fprintf(ExpLog,'%24s %6d\r\n','Number of trial',MaxTrial);
    fprintf(ExpLog,'%24s %6d\r\n','Number of real',realTrial);
    fprintf(ExpLog,'%24s %6d\r\n','Number of sham',shamTrial);
    fprintf(ExpLog,'%24s %6d\r\n','RewValve open time (ms)',rewSolDur);
    fprintf(ExpLog,'%24s %6d\r\n','Reward Delay Freq (%)',rewDelayFreq);
    maxDelay = (maxDelay-1)*250;
    fprintf(ExpLog,'%24s %6d\r\n','Maximal delay (ms)',maxDelay);
    fprintf(ExpLog,'%24s %6d\r\n','Rew/Pun switch freq (%)',rewPunSwitch);
    fprintf(ExpLog,'%24s %6d\r\n','Reward Skip Freq (%)',rewSolSkip);

    fclose(ExpLog);

    T= [Trial(:)];
    excelname = strcat(filename,"_log.xlsx");
    writetable(struct2table(T),excelname);

%%end
clear('Trial');
disp("Finished");


