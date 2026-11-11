// Define the number of floors and elevatorsin the building
#define NUM_FLOORS 3
#define NUM_ELEVATORS 1

// Define the possible states of the elevator
// mtype = {IDLE, MOVING_UP, MOVING_DOWN};

// Define the state variables for the elevator
byte elevator_floor[NUM_ELEVATORS];
// mtype elevator_state[NUM_ELEVATORS];
// Define the state variables for the doors
bit doorisopen[NUM_FLOORS * NUM_ELEVATORS];

// Define the channels for communication between the elevator
// and the doors. {floor, elevator_id, door_state}
chan openclosedoor = [0] of {byte, byte, bit};

// Door (floor, elevator) process
proctype door(byte f; byte e) {
    do
    // Wait for a message from the elevator to open or close the door
    // Open the door
    ::  openclosedoor?eval(f),eval(e),1;
        doorisopen[(f-1)*NUM_ELEVATORS + (e-1)] = 1;
        openclosedoor!f,e,1;
    // Close the door
    ::  openclosedoor?eval(f),eval(e),0;
        doorisopen[(f-1)*NUM_ELEVATORS + (e-1)] = 0;
        openclosedoor!f,e,0;
    od
}

// Elevator (id) process
proctype elevator(byte id) {
    do
    // Move the elevator up or down one floor, if possible
    // Move up
    ::  (elevator_floor[id-1] < NUM_FLOORS &&
        doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 0) -> elevator_floor[id-1]++;
    // Move down
    ::  (elevator_floor[id-1] > 1 &&
        doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 0) -> elevator_floor[id-1]--;
    // Open or close the door on the current floor, if possible
    // Open the door
    ::  (doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 0) -> 
        openclosedoor!elevator_floor[id-1],id,1;
        openclosedoor?eval(elevator_floor[id-1]),eval(id),0;
    // Close the door
    ::  (doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 1) -> 
        openclosedoor!elevator_floor[id-1],id,0;
        openclosedoor?eval(elevator_floor[id-1]),eval(id),0
    od
}

// Initialize the state variables and start the processes
init {
    atomic {
        elevator_floor[0] = 1;
        // elevator_state[0] = IDLE;

        run door(1, 1);
        run door(2, 1);
        run door(3, 1);

        run elevator(1);
    }
}


// Declare macros for later Verification
// #define open1 doorisopen[0, 0]
// #define close1 !doorisopen[0, 0]

// #define open2 doorisopen[1, 0]
// #define close2 !doorisopen[1, 0]

// #define open3 doorisopen[2, 0]
// #define close3 !doorisopen[2, 0]

// // Declare LTL properties for verification
// ltl alldooropen {
//  [] (!open3)
// }
