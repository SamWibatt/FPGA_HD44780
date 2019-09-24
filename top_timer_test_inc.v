//this is meant to be `included from hd44780_top

//*****************************************************************************************
//NOW STUFF FOR TESTING THE LCD PINS!
//WHICH IS THE ENTIRE POINT OF ALL OF THIS!
reg lcd_rs_reg = 0;
reg lcd_e_reg = 0;
reg [3:0] lcd_data_reg = 4'b0000;
//*****************************************************************************************

//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//FIGURE OUT HOW TO DO IF TARGET = TIMER HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//state timer test
reg [`H4_TIMER_BITS-1:0] st_dat = 0;
reg st_start_stb = 0;
wire st_end_stb;

hd44780_state_timer timey(
    .RST_I(wb_reset),
    .CLK_I(wb_clk),
    .DAT_I(st_dat),
    .start_strobe(st_start_stb),            // causes timer to load
    .end_strobe(st_end_stb)             // nudges caller to advance state
    );

reg [2:0] ttest_state = 0;
localparam tt_idle = 0, tt_loadtm = 3'b001, tt_waitend = 3'b010,
    tt_loadtm2 = 3'b011, tt_waitend2 = 3'b100,
    tt_loadtm3 = 3'b101, tt_waitend3 = 3'b110,
    tt_lockup = 3'b111;

always @(posedge clk) begin
    //SEE below for button stuff.
    //assume that if button has been pressed, we're not in wb_reset.
    if(button_has_been_pressed) begin

        //downcount data reg just to have it have something to do
        lcd_data_reg <= lcd_data_reg - 1;

        case (ttest_state)
            tt_idle: begin
                //so... given we're not in reset, step on out.
                ttest_state <= tt_loadtm;
            end

            tt_loadtm: begin
                lcd_rs_reg <= 1;       //now let's use RS to track the outer state machine here, why not
                //timer test
                st_dat <= 114;       //arbitrary number. We want this many system ticks bt strobe drop and strobe out.
                st_start_stb <= 1;
                ttest_state <= tt_waitend;
            end

            tt_waitend: begin
                st_start_stb <= 0;
                if(st_end_stb) begin
                    ttest_state = tt_loadtm2;
                end
            end

            tt_loadtm2: begin
                lcd_rs_reg <= 1;       //now let's use RS to track the outer state machine here, why not
                //timer test
                st_dat <= 1;       //arbitrary number. We want this many system ticks bt strobe drop and strobe out.
                st_start_stb <= 1;
                ttest_state <= tt_waitend2;
            end

            tt_waitend2: begin
                st_start_stb <= 0;
                if(st_end_stb) begin
                    ttest_state = tt_loadtm3;
                end
            end

            tt_loadtm3: begin
                lcd_rs_reg <= 1;       //now let's use RS to track the outer state machine here, why not
                //timer test
                st_dat <= 0;       //arbitrary number. We want this many system ticks bt strobe drop and strobe out.
                st_start_stb <= 1;
                ttest_state <= tt_waitend3;
            end

            tt_waitend3: begin
                st_start_stb <= 0;
                if(st_end_stb) begin
                    ttest_state = tt_lockup;
                end
            end


            tt_lockup: begin
                //nothing happens HERE. used to go to idle, which gave us infinity timer calls, so if you want that, etc.
                lcd_rs_reg <= 0;         //using rs to track when this state machine is active
                st_start_stb <= 0;
            end

            default: begin
                ttest_state <= tt_idle;
                st_start_stb <= 0;
                st_dat <= 0;
            end
        endcase

        /* this was the first LA test
        //meaningless but logic-analyzer-capturable signals that will start when button is pressed,
        //see below.
        lcd_e_reg <= ~lcd_e_reg;
        lcd_rs_reg <= lcd_data_reg[1];
        lcd_data_reg <= lcd_data_reg + 1;
        */
    end else begin
        //button has NOT been pressed, which amounts to reset.
        ttest_state <= tt_idle;
        st_start_stb <= 0;
        st_dat <= 0;
        lcd_e_reg <= 0;     //mirror end strobe with lcd e for LA vis
        lcd_rs_reg <= 0;    //mirror start strobe with lcd RS reg, for LA visibility.
    end
end

//wire lcd_rs;                 //R/S pin - R/~W is tied low
assign lcd_rs = lcd_rs_reg; // was st_start_stb;   //mirror start strobe with rs for LA visibility - was lcd_rs_reg;
//wire lcd_e;                  //enable!
assign lcd_e = st_end_stb | st_start_stb;  //mirror START AND end strobe with e for LA visitbility - was lcd_e_reg;
//wire [3:0] lcd_data;         //data
assign lcd_data = lcd_data_reg;     //What's something interesting to do with lcd_data_reg? currently counting

// TESTER OF ALL LEDs =======================================================================================
// Super simple "I'm Alive" blinky on one of the external LEDs. Copied from controller
parameter GREENBLINKBITS = `H4_TIMER_BITS + 2;		//see if can adjust to sim or build clock speed			//25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
                                        // and hey why not define that in top or tb instead of in the controller or even on command line - ok
                                        // now the define above is wrapped in `ifndef G_SYSFREQ so there you go
reg[GREENBLINKBITS-1:0] greenblinkct = 0;
always @(posedge clk) begin
    greenblinkct <= greenblinkct + 1;
end

assign led_g_outwire = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this - this line causes multiple driver problem
assign led_b_outwire = greenblinkct[GREENBLINKBITS-1];
assign led_r_outwire = ~greenblinkct[GREENBLINKBITS-2];

//STUFF THAT SHUTS UP THE WARNINGS ABOUT UNUSUED PORTS -
reg reg_led0 = 0;
reg reg_led1 = 0;
reg reg_led2 = 0;
reg reg_led3 = 0;

//mad alive blinkies

always @(posedge clk) begin
    if(button_has_been_pressed) begin
        //for top pure blinky, set all active low other-blinkies to off
        //this was failing with the assigns below when I had <= 1 here; bad driver sort of sitch?
        reg_led0 <= greenblinkct[GREENBLINKBITS-2];
        reg_led1 <= ~greenblinkct[GREENBLINKBITS-3];
        reg_led2 <= greenblinkct[GREENBLINKBITS-3];
        reg_led3 <= ~greenblinkct[GREENBLINKBITS-4];
    end else begin
        // glue LEDs off
        reg_led0 <= 1;
        reg_led1 <= 1;
        reg_led2 <= 1;
        reg_led3 <= 1;
    end
end

//wire o_led0;     //set_io o_led0 36
assign o_led0 = reg_led0;     //act low
//wire o_led1;     //set_io o_led1 42
assign o_led1 = reg_led1;     //act low
//wire o_led2;     //set_io o_led2 38
assign o_led2 = reg_led2;     //act low
//wire o_led3;     //set_io o_led3 28
assign o_led3 = reg_led3;     //act low

// END TESTER OF ALL LEDs ===================================================================================
