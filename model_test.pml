1	#define NUM_FLOORS 5
2	#define NUM_ELEVATORS 2
3	
4	// Elevator state variables
5	byte elevator_floor[NUM_ELEVATORS];
6	
7	// Door and request state variables
8	bit doorisopen[NUM_FLOORS * NUM_ELEVATORS];
9	bit ext_request[NUM_FLOORS];
10	bit int_request[NUM_ELEVATORS * NUM_FLOORS];
11	
12	// CPU scheduling variable
13	byte turn = 1;
14	
15	// Communication channel: {floor, elevator_id, door_state}
16	chan openclosedoor = [0] of {byte, byte, bit};
17	
18	// Check if there is an external or internal request at floor index (0 to 4)
19	#define HAS_REQ(id, f_idx) (ext_request[f_idx] == 1 || int_request[((id)-1)*NUM_FLOORS + (f_idx)] == 1)
20	
21	// Check if there are requests above current floor (1 to 5)
22	#define REQ_ABOVE(id, curr) ( \
23	    ((curr) <= 1 && HAS_REQ(id, 1)) || \
24	    ((curr) <= 2 && HAS_REQ(id, 2)) || \
25	    ((curr) <= 3 && HAS_REQ(id, 3)) || \
26	    ((curr) <= 4 && HAS_REQ(id, 4)) \
27	)
28	
29	// Check if there are requests below current floor (1 to 5)
30	#define REQ_BELOW(id, curr) ( \
31	    ((curr) >= 2 && HAS_REQ(id, 0)) || \
32	    ((curr) >= 3 && HAS_REQ(id, 1)) || \
33	    ((curr) >= 4 && HAS_REQ(id, 2)) || \
34	    ((curr) >= 5 && HAS_REQ(id, 3)) \
35	)
36	
37	// Check whether an elevator has any valid action to execute
38	#define CAN_ACT(e) ( \
39	    doorisopen[(elevator_floor[(e)-1]-1)*NUM_ELEVATORS + ((e)-1)] == 1 || \
40	    HAS_REQ(e, elevator_floor[(e)-1]-1) || \
41	    REQ_ABOVE(e, elevator_floor[(e)-1]) || \
42	    REQ_BELOW(e, elevator_floor[(e)-1]) \
43	)
44	
45	// Door process
46	proctype door(byte f; byte e) {
47	    do
48	    :: openclosedoor?eval(f),eval(e),1;
49	       doorisopen[(f-1)*NUM_ELEVATORS + (e-1)] = 1;
50	       printf("Door at floor %d, elevator %d opened.\n", f, e);
51	       openclosedoor!f,e,1;
52	
53	    :: openclosedoor?eval(f),eval(e),0;
54	       doorisopen[(f-1)*NUM_ELEVATORS + (e-1)] = 0;
55	       printf("Door at floor %d, elevator %d closed.\n", f, e);
56	       openclosedoor!f,e,0;
57	    od
58	}
59	
60	// Elevator process with Round Robin, skip, and request-driven movement
61	proctype elevator(byte id) {
62	    do
63	    // Move up - atomic
64	    :: atomic {
65	        ((turn == id || !CAN_ACT(3-id)) &&
66	         elevator_floor[id-1] < NUM_FLOORS &&
67	         doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 0 &&
68	         REQ_ABOVE(id, elevator_floor[id-1]) &&
69	         !HAS_REQ(id, elevator_floor[id-1]-1));
70	
71	        elevator_floor[id-1]++;
72	        printf("Elevator %d moved up to floor %d.\n",
73	               id, elevator_floor[id-1]);
74	        turn = 3 - id;
75	    }
76	
77	    // Move down - atomic
78	    :: atomic {
79	        ((turn == id || !CAN_ACT(3-id)) &&
80	         elevator_floor[id-1] > 1 &&
81	         doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 0 &&
82	         REQ_BELOW(id, elevator_floor[id-1]) &&
83	         !HAS_REQ(id, elevator_floor[id-1]-1));
84	
85	        elevator_floor[id-1]--;
86	        printf("Elevator %d moved down to floor %d.\n",
87	               id, elevator_floor[id-1]);
88	        turn = 3 - id;
89	    }
90	
91	    // Open door and clear floor requests
92	    :: ((turn == id || !CAN_ACT(3-id)) &&
93	        doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 0 &&
94	        HAS_REQ(id, elevator_floor[id-1]-1)) ->
95	
96	        printf("Elevator %d requests to open its door at floor %d.\n",
97	               id, elevator_floor[id-1]);
98	
99	        openclosedoor!elevator_floor[id-1],id,1;
100	        openclosedoor?eval(elevator_floor[id-1]),eval(id),1;
101	
102	        atomic {
103	            ext_request[elevator_floor[id-1]-1] = 0;
104	            int_request[(id-1)*NUM_FLOORS + elevator_floor[id-1]-1] = 0;
105	            printf("Requests served at floor %d by elevator %d.\n",
106	                   elevator_floor[id-1], id);
107	            turn = 3 - id;
108	        }
109	
110	    // Close door
111	    :: ((turn == id || !CAN_ACT(3-id)) &&
112	        doorisopen[(elevator_floor[id-1]-1)*NUM_ELEVATORS + (id-1)] == 1) ->
113	
114	        printf("Elevator %d requests to close its door at floor %d.\n",
115	               id, elevator_floor[id-1]);
116	
117	        openclosedoor!elevator_floor[id-1],id,0;
118	        openclosedoor?eval(elevator_floor[id-1]),eval(id),0;
119	        turn = 3 - id;
120	    od
121	}
122	
123	// External request process
124	proctype external_request(byte f) {
125	    do
126	    :: (ext_request[f-1] == 0) ->
127	        ext_request[f-1] = 1;
128	        printf("External request registered at floor %d.\n", f);
129	    od
130	}
131	
132	// Internal request process
133	proctype internal_request(byte e; byte f) {
134	    do
135	    :: (int_request[(e-1)*NUM_FLOORS + (f-1)] == 0) ->
136	        int_request[(e-1)*NUM_FLOORS + (f-1)] = 1;
137	        printf("Internal request registered: elevator %d, floor %d.\n", e, f);
138	    od
139	}
140	
141	// Initialize system
142	init {
143	    atomic {
144	        printf("Elevator system initialized with %d floors and %d elevators.\n",
145	               NUM_FLOORS, NUM_ELEVATORS);
146	
147	        elevator_floor[0] = 1;
148	        elevator_floor[1] = 1;
149	        turn = 1;
150	
151	        run elevator(1);
152	        run elevator(2);
153	
154	        run door(1, 1);
155	        run door(2, 1);
156	        run door(3, 1);
157	        run door(4, 1);
158	        run door(5, 1);
159	
160	        run door(1, 2);
161	        run door(2, 2);
162	        run door(3, 2);
163	        run door(4, 2);
164	        run door(5, 2);
165	
166	        run external_request(1);
167	        run external_request(2);
168	        run external_request(3);
169	        run external_request(4);
170	        run external_request(5);
171	
172	        run internal_request(1, 1);
173	        run internal_request(1, 2);
174	        run internal_request(1, 3);
175	        run internal_request(1, 4);
176	        run internal_request(1, 5);
177	
178	        run internal_request(2, 1);
179	        run internal_request(2, 2);
180	        run internal_request(2, 3);
181	        run internal_request(2, 4);
182	        run internal_request(2, 5);
183	
184	        doorisopen[0] = 0;
185	        doorisopen[1] = 0;
186	        doorisopen[2] = 0;
187	        doorisopen[3] = 0;
188	        doorisopen[4] = 0;
189	        doorisopen[5] = 0;
190	        doorisopen[6] = 0;
191	        doorisopen[7] = 0;
192	        doorisopen[8] = 0;
193	        doorisopen[9] = 0;
194	
195	        ext_request[0] = 0;
196	        ext_request[1] = 0;
197	        ext_request[2] = 0;
198	        ext_request[3] = 0;
199	        ext_request[4] = 0;
200	
201	        int_request[0] = 0;
202	        int_request[1] = 0;
203	        int_request[2] = 0;
204	        int_request[3] = 0;
205	        int_request[4] = 0;
206	        int_request[5] = 0;
207	        int_request[6] = 0;
208	        int_request[7] = 0;
209	        int_request[8] = 0;
210	        int_request[9] = 0;
211	    }
212	}
213	
214	// Verification macros
215	#define open1 (doorisopen[0] == 1)
216	#define close1 (doorisopen[0] == 0)
217	
218	#define open2 (doorisopen[2] == 1)
219	#define close2 (doorisopen[2] == 0)
220	
221	#define open3 (doorisopen[4] == 1)
222	#define close3 (doorisopen[4] == 0)
223	
224	#define ext_req_floor_1 (ext_request[0] == 1)
225	#define any_door_open_floor_1 (doorisopen[0] == 1 || doorisopen[1] == 1)
226	#define elev_1_at_floor_2 (elevator_floor[0] == 2)
227	
228	// LTL Properties
229	ltl guaranteed_service {
230	    [] (ext_req_floor_1 -> <> any_door_open_floor_1)
231	}
232	
233	ltl physical_consistency {
234	    [] (open2 -> elev_1_at_floor_2)
235	}
