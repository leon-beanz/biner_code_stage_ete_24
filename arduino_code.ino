//GLOBALS
//time constants (all in milliseconds)
const int sound_time = 1500;
const int pause_after_sound = 200; //time before we start detecting licks after the sound starts playing
const int time_allocated_lick = 3000; //time given for mouse to lick 
const int wait_added_for_punish = 3000;
const int time_valve_open = 100; // time for valve to open
const int wait_before_camera = 494; //time to sync camera to sound
const int wait_before_stimulation = 1000 - wait_before_camera ;
const int wait_between_trials = 3000 - time_valve_open; //You can ajust the time the valve is open without affecting total time
const int time_without_lick_to_proceed = 1000;
const int time_out_serial_comm = 100;
//pins
const byte reward_pin_1 = 12;
const byte reward_pin_2 = 13;
const byte lick_pin = 8;
const byte raspberryPi_pin = 4;
//others
const String program_name = "Go No-Go Training";
const byte max_trial = 20; //maximum number of trials
const byte real_trial_percentage = 60;
//number of real or sham trials, updated in setup()
byte real_trial = 0;
byte sham_trial = 0;
byte trial_number = 0; //what trial are we at

//DATA STRUCTURES
struct TrialData { //each trial, this represents that specific trial's data
    TrialData() : response(false), lick_time(0), result("null"),
                  reward(false), reward_time(0), stimulation_time(0) {}
    bool response; //true if licked
    long unsigned int lick_time; //0 if no lick
    String result;
    bool reward; 
    long unsigned int reward_time; //0 if no reward for the trial
    long unsigned int stimulation_time;
};

//FUNCTION DECLARATIONS
void goTrial(TrialData*);
void noGoTrial(TrialData*);
void reward(); //has the time_valve_open delay inside
void punish();
bool detectLick(TrialData*); //updates lick_time data member
byte initialiseTrial(); //returns 2 if noGo trial and 1 if Go
void openCamera();
void prepMatlabForTrial(int); //takes the type as an argument
void sendTrialDataToMatlab(TrialData*, long unsigned int, long unsigned int);
void setupMatlab();


void setup() 
{
    pinMode(lick_pin, INPUT);
    pinMode(reward_pin_1, OUTPUT);
    pinMode(reward_pin_2, OUTPUT);
    pinMode(raspberryPi_pin, OUTPUT);
    digitalWrite(reward_pin_1, LOW);
    digitalWrite(reward_pin_2,HIGH);
    digitalWrite(raspberryPi_pin, LOW);

    Serial.begin(9600);
    Serial.setTimeout(time_out_serial_comm);
    Serial.println("Communication test");
    Serial.println("Connected?");
    char comm = 'n';
    while (comm != 'y')
    {
        comm = Serial.read();
    }
    real_trial = byte(round(float(max_trial) * float(real_trial_percentage) / 100.0));
    sham_trial = max_trial - real_trial;
    setupMatlab();
}

void loop() 
{
    TrialData data;
    TrialData* data_ptr = &data;
    int type = initialiseTrial();
    prepMatlabForTrial(type);
    long unsigned int trial_start = millis();
    delay(wait_before_camera);
    openCamera();
    delay(wait_before_stimulation);

    if (type == 1)
        goTrial(data_ptr);
    else
        noGoTrial(data_ptr);
    long unsigned int trial_end = millis();
    sendTrialDataToMatlab(data_ptr, trial_start, trial_end);
    delay(wait_between_trials);
}



//FUNCTION DEFINITIONS
void goTrial(TrialData* data)
{
    Serial.println("Trial start");
    Serial.println("play_10khz"); //tell matlab to play go sound
    data->stimulation_time = millis();
    delay(pause_after_sound); //the delay (200ms) before detecting licks
    if (detectLick(data)) // if we detect a lick
    {
        data->response = true;
        data->reward = true;
        data->reward_time = millis();
        reward();
        data->result = "Correct-REWARD";
        return;
    }
    delay(time_valve_open); //to account for reward() function's execution time
    data->result = "Miss";
}

void noGoTrial(TrialData* data)
{
    Serial.println("Trial start");
    Serial.println("play_5khz");
    data->stimulation_time = millis();
    delay(pause_after_sound);
    if (detectLick(data)) // if lick detected
    {
        data->response = true;
        punish();
        data->result = "FalseAlarm-Punish";
    }
    else
        data->result = "CorrectReject";
    delay(time_valve_open); // sync total time to Go Trial
}

void reward()
{
    digitalWrite(reward_pin_1, HIGH);
    digitalWrite(reward_pin_2, LOW);
    delay(time_valve_open);
    digitalWrite(reward_pin_1, LOW);
    digitalWrite(reward_pin_2, HIGH);
}

void punish()
{
    int time_since_lick = 0;
    int last_lick = millis();
    while (time_since_lick < time_without_lick_to_proceed) // while loop cont. until there are not licks for time_without_lick_to_proceed
    {
        if (!digitalRead(lick_pin)) //inverse logic with capacitive sensor
        {
            last_lick = millis();
        }
        time_since_lick = millis() - last_lick; //Checks how long it's been since last lick
    }
    delay(wait_added_for_punish);
}

bool detectLick(TrialData* data)
{
    int elapsed_time = 0;
    int start_time = millis();
    bool licked = false;
    while (elapsed_time < time_allocated_lick)
    {
        if (!digitalRead(lick_pin)) // if there is lick
        {
            //if (licked == false)
            if (!licked) // if its the first detected lick
                data->lick_time = millis();
            licked = true;
        }
        elapsed_time = millis() - start_time;
    }
    return licked;
}

byte initialiseTrial()
{
    trial_number++;
    Serial.print(" - Trial #");
    Serial.print(trial_number);
    Serial.println(" - ");
    Serial.println("Type?");

    while (!Serial.available()) {}
    int r = Serial.read();
    Serial.print("Available : ");
    Serial.println(r);
    if (r <= real_trial)
    {
        return  1;
    }
    return 2;
}

void openCamera()
{
    digitalWrite(raspberryPi_pin, HIGH);
    delay(1);
    digitalWrite(raspberryPi_pin, LOW);
}

void prepMatlabForTrial(int type)
{
    Serial.print("Trial type:");
    Serial.println(type);
    Serial.println("rdy?");
    //wait for matlab to get ready
    while (Serial.read() != 'y') {} //once matlab is ready (sent 'y'), trial starts
}

void sendTrialDataToMatlab(TrialData* data, long unsigned trial_start, long unsigned trial_end)
{
    Serial.print("Trial Start:");
    Serial.println(trial_start);
    Serial.print("Stim Time:");
    Serial.println(data->stimulation_time);
    Serial.print("Trial End:");
    Serial.println(trial_end);
    Serial.print("Response:");
    if (data->response == 0)
        Serial.println("NoLick");
    else
    {
        Serial.println("Lick");
        Serial.print("LickTime:");
        Serial.println(data->lick_time);
    }
    Serial.print("Result:");
    Serial.println(data->result);
    if (data->reward == 1)
    {
        Serial.print("rewDelay:");
        Serial.println(0);
        Serial.print("rewTime:");
        Serial.println(data->reward_time);    
    }
    Serial.println();
    Serial.println(" - ITI - ");
    Serial.println();
}

void setupMatlab()
{
    Serial.print("Protocol name:");
    Serial.println(program_name);
    Serial.println();
    Serial.println("TASK PARAMETERS");
    Serial.print("stimDur:");
    Serial.println(time_allocated_lick);
    Serial.print("preStim:");
    Serial.println(0);
    Serial.print("postStim:");
    Serial.println(0);
    Serial.print("iti:");
    Serial.println(0);
    Serial.print("MaxTrial:");
    Serial.println(max_trial);
    Serial.print("realTrial:");
    Serial.println(real_trial);
    Serial.print("shamTrial:");
    Serial.println(sham_trial);
    Serial.print("rewSolDur:");
    Serial.println(time_valve_open);
    Serial.print("rewDelayFreq:");
    Serial.println(0);
    Serial.print("maxDelay:");
    Serial.println(0);
    Serial.print("rewPunSwitch:");
    Serial.println(0);
    Serial.print("rewSolSkip:");
    Serial.println(0);
    Serial.println();
}