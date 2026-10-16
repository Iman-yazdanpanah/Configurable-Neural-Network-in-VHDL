library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.ALL;

entity mlp_memory_tb is
end mlp_memory_tb;

architecture Simulation of mlp_memory_tb is

    constant DATA_WIDTH     : positive := 16;
    constant FRAC_BITS      : natural  := 9;
    constant N_INPUTS       : positive := 2;
    constant HIDDEN_NEURONS : positive := 3;
    constant OUTPUT_NEURONS : positive := 2;

    constant HIDDEN_WEIGHTS : positive :=
        N_INPUTS * HIDDEN_NEURONS;

    constant OUTPUT_WEIGHTS : positive :=
        HIDDEN_NEURONS * OUTPUT_NEURONS;

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1';
    signal start : STD_LOGIC := '0';

    signal inputs : STD_LOGIC_VECTOR(
        N_INPUTS*DATA_WIDTH-1 downto 0
    ) := (others => '0');

    ------------------------------------------------------------------
    -- Hidden-layer initialization interface
    ------------------------------------------------------------------
    signal hidden_weight_write_enable : STD_LOGIC := '0';

    signal hidden_weight_write_addr :
        integer range 0 to HIDDEN_WEIGHTS-1 := 0;

    signal hidden_weight_write_data :
        SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');

    signal hidden_bias_write_enable : STD_LOGIC := '0';

    signal hidden_bias_write_addr :
        integer range 0 to HIDDEN_NEURONS-1 := 0;

    signal hidden_bias_write_data :
        SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');

    ------------------------------------------------------------------
    -- Output-layer initialization interface
    ------------------------------------------------------------------
    signal output_weight_write_enable : STD_LOGIC := '0';

    signal output_weight_write_addr :
        integer range 0 to OUTPUT_WEIGHTS-1 := 0;

    signal output_weight_write_data :
        SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');

    signal output_bias_write_enable : STD_LOGIC := '0';

    signal output_bias_write_addr :
        integer range 0 to OUTPUT_NEURONS-1 := 0;

    signal output_bias_write_data :
        SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');

    ------------------------------------------------------------------
    -- Inference outputs
    ------------------------------------------------------------------
    signal hidden_activations : STD_LOGIC_VECTOR(
        HIDDEN_NEURONS*DATA_WIDTH-1 downto 0
    );

    signal outputs : STD_LOGIC_VECTOR(
        OUTPUT_NEURONS*DATA_WIDTH-1 downto 0
    );

    signal busy : STD_LOGIC;
    signal done : STD_LOGIC;

begin

    ------------------------------------------------------------------
    -- Clock: 10 ns period
    ------------------------------------------------------------------
    clk <= not clk after 5 ns;


    ------------------------------------------------------------------
    -- Device under test
    ------------------------------------------------------------------
    DUT : entity work.mlp_memory
        generic map (
            DATA_WIDTH     => DATA_WIDTH,
            FRAC_BITS      => FRAC_BITS,
            N_INPUTS       => N_INPUTS,
            HIDDEN_NEURONS => HIDDEN_NEURONS,
            OUTPUT_NEURONS => OUTPUT_NEURONS,
            ACC_WIDTH      => 40
        )
        port map (
            clk   => clk,
            reset => reset,
            start => start,

            inputs => inputs,

            ----------------------------------------------------------
            -- Hidden-layer initialization
            ----------------------------------------------------------
            hidden_weight_write_enable =>
                hidden_weight_write_enable,

            hidden_weight_write_addr =>
                hidden_weight_write_addr,

            hidden_weight_write_data =>
                hidden_weight_write_data,

            hidden_bias_write_enable =>
                hidden_bias_write_enable,

            hidden_bias_write_addr =>
                hidden_bias_write_addr,

            hidden_bias_write_data =>
                hidden_bias_write_data,

            ----------------------------------------------------------
            -- Output-layer initialization
            ----------------------------------------------------------
            output_weight_write_enable =>
                output_weight_write_enable,

            output_weight_write_addr =>
                output_weight_write_addr,

            output_weight_write_data =>
                output_weight_write_data,

            output_bias_write_enable =>
                output_bias_write_enable,

            output_bias_write_addr =>
                output_bias_write_addr,

            output_bias_write_data =>
                output_bias_write_data,

            ----------------------------------------------------------
            -- Inference results
            ----------------------------------------------------------
            outputs => outputs,

            hidden_activations => hidden_activations,

            ----------------------------------------------------------
            -- Backpropagation read port
            -- Unused in this inference-only testbench
            ----------------------------------------------------------
            output_weight_read_addr => 0,
            output_weight_read_data => open,

            ----------------------------------------------------------
            -- Hidden-layer training access
            -- Disabled in this inference-only testbench
            ----------------------------------------------------------
            hidden_parameter_read_enable  => '0',
            hidden_parameter_read_address => 0,
            hidden_parameter_read_data    => open,

            hidden_parameter_write_enable  => '0',
            hidden_parameter_write_address => 0,
            hidden_parameter_write_data    =>
                to_signed(0, DATA_WIDTH),

            ----------------------------------------------------------
            -- Output-layer training access
            -- Disabled in this inference-only testbench
            ----------------------------------------------------------
            output_parameter_read_enable  => '0',
            output_parameter_read_address => 0,
            output_parameter_read_data    => open,

            output_parameter_write_enable  => '0',
            output_parameter_write_address => 0,
            output_parameter_write_data    =>
                to_signed(0, DATA_WIDTH),

            busy => busy,
            done => done
        );


    ------------------------------------------------------------------
    -- Test stimulus
    ------------------------------------------------------------------
    stimulus : process
    begin

        --------------------------------------------------------------
        -- TEST 1: Reset
        --------------------------------------------------------------
        reset <= '1';
        start <= '0';

        wait for 20 ns;
        wait until falling_edge(clk);

        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '0' and done = '0'
            report "TEST 1 FAILED: Incorrect reset status"
            severity failure;

        report "TEST 1 PASSED: Reset"
            severity note;


        --------------------------------------------------------------
        -- TEST 2: Load hidden-layer weights
        --
        -- Address 0: neuron 0, input 0 =  1.0
        -- Address 1: neuron 0, input 1 =  1.0
        -- Address 2: neuron 1, input 0 =  2.0
        -- Address 3: neuron 1, input 1 = -1.0
        -- Address 4: neuron 2, input 0 = -1.0
        -- Address 5: neuron 2, input 1 =  2.0
        --------------------------------------------------------------
        for i in 0 to HIDDEN_WEIGHTS-1 loop

            wait until falling_edge(clk);

            hidden_weight_write_enable <= '1';
            hidden_weight_write_addr   <= i;

            case i is

                when 0 =>
                    hidden_weight_write_data <=
                        to_signed(512, DATA_WIDTH);

                when 1 =>
                    hidden_weight_write_data <=
                        to_signed(512, DATA_WIDTH);

                when 2 =>
                    hidden_weight_write_data <=
                        to_signed(1024, DATA_WIDTH);

                when 3 =>
                    hidden_weight_write_data <=
                        to_signed(-512, DATA_WIDTH);

                when 4 =>
                    hidden_weight_write_data <=
                        to_signed(-512, DATA_WIDTH);

                when others =>
                    hidden_weight_write_data <=
                        to_signed(1024, DATA_WIDTH);

            end case;

            wait until rising_edge(clk);

        end loop;

        wait until falling_edge(clk);
        hidden_weight_write_enable <= '0';


        --------------------------------------------------------------
        -- Hidden biases: all zero
        --------------------------------------------------------------
        for i in 0 to HIDDEN_NEURONS-1 loop

            wait until falling_edge(clk);

            hidden_bias_write_enable <= '1';
            hidden_bias_write_addr   <= i;
            hidden_bias_write_data   <= to_signed(0, DATA_WIDTH);

            wait until rising_edge(clk);

        end loop;

        wait until falling_edge(clk);
        hidden_bias_write_enable <= '0';


        --------------------------------------------------------------
        -- TEST 3: Load output-layer weights
        --
        -- Neuron 0 weights: [1, 2, -1]
        -- Neuron 1 weights: [2, 0,  1]
        --------------------------------------------------------------
        for i in 0 to OUTPUT_WEIGHTS-1 loop

            wait until falling_edge(clk);

            output_weight_write_enable <= '1';
            output_weight_write_addr   <= i;

            case i is

                when 0 =>
                    output_weight_write_data <=
                        to_signed(512, DATA_WIDTH);

                when 1 =>
                    output_weight_write_data <=
                        to_signed(1024, DATA_WIDTH);

                when 2 =>
                    output_weight_write_data <=
                        to_signed(-512, DATA_WIDTH);

                when 3 =>
                    output_weight_write_data <=
                        to_signed(1024, DATA_WIDTH);

                when 4 =>
                    output_weight_write_data <=
                        to_signed(0, DATA_WIDTH);

                when others =>
                    output_weight_write_data <=
                        to_signed(512, DATA_WIDTH);

            end case;

            wait until rising_edge(clk);

        end loop;

        wait until falling_edge(clk);
        output_weight_write_enable <= '0';


        --------------------------------------------------------------
        -- Output biases: 0 and 1.0
        --------------------------------------------------------------
        for i in 0 to OUTPUT_NEURONS-1 loop

            wait until falling_edge(clk);

            output_bias_write_enable <= '1';
            output_bias_write_addr   <= i;

            if i = 0 then
                output_bias_write_data <= to_signed(0, DATA_WIDTH);
            else
                output_bias_write_data <= to_signed(512, DATA_WIDTH);
            end if;

            wait until rising_edge(clk);

        end loop;

        wait until falling_edge(clk);
        output_bias_write_enable <= '0';

        report "TEST 2 PASSED: Both parameter memories loaded"
            severity note;


        --------------------------------------------------------------
        -- TEST 4: Apply inputs x0 = 1.0, x1 = 2.0
        --
        -- Input 0 occupies the lowest DATA_WIDTH bits.
        --------------------------------------------------------------
        inputs(DATA_WIDTH-1 downto 0) <=
            std_logic_vector(to_signed(512, DATA_WIDTH));

        inputs(2*DATA_WIDTH-1 downto DATA_WIDTH) <=
            std_logic_vector(to_signed(1024, DATA_WIDTH));


        --------------------------------------------------------------
        -- TEST 5: Start inference
        --------------------------------------------------------------
        wait until falling_edge(clk);
        start <= '1';

        wait until falling_edge(clk);
        start <= '0';

        -- Wait for completion, with timeout.
        for i in 0 to 100 loop

            wait until rising_edge(clk);
            wait for 1 ns;

            exit when done = '1';

        end loop;

        assert done = '1'
            report "TEST FAILED: Network inference timed out"
            severity failure;

        assert busy = '0'
            report "TEST FAILED: Busy still asserted at completion"
            severity failure;

        report "TEST 3 PASSED: Network inference completed"
            severity note;


        --------------------------------------------------------------
        -- Expected hidden activations:
        --
        -- h0 = 1*1 + 1*2  = 3
        -- h1 = 2*1 - 1*2  = 0
        -- h2 = -1*1 + 2*2 = 3
        --
        -- ReLU outputs: [3, 0, 3]
        --
        -- Output 0 = 1*3 + 2*0 - 1*3 = 0
        -- Output 1 = 2*3 + 0*0 + 1*3 + 1 = 10
        --------------------------------------------------------------
        report "Hidden activations (raw Q9): " &
            integer'image(to_integer(
                signed(hidden_activations(15 downto 0))
            )) & ", " &
            integer'image(to_integer(
                signed(hidden_activations(31 downto 16))
            )) & ", " &
            integer'image(to_integer(
                signed(hidden_activations(47 downto 32))
            ))
            severity note;


        --------------------------------------------------------------
        -- TEST 6: Verify output neuron 0 = 0
        --------------------------------------------------------------
        assert signed(outputs(DATA_WIDTH-1 downto 0)) =
               to_signed(0, DATA_WIDTH)
            report "TEST FAILED: Output neuron 0 should equal 0"
            severity failure;

        report "TEST 4 PASSED: Output neuron 0 = 0"
            severity note;


        --------------------------------------------------------------
        -- TEST 7: Verify output neuron 1 = 10.0
        --------------------------------------------------------------
        assert signed(
            outputs(2*DATA_WIDTH-1 downto DATA_WIDTH)
        ) = to_signed(5120, DATA_WIDTH)
            report "TEST FAILED: Output neuron 1 should equal 10.0"
            severity failure;

        report "TEST 5 PASSED: Output neuron 1 = 10.0"
            severity note;

        report "ALL MLP MEMORY TESTS PASSED"
            severity note;

        wait;

    end process;

end Simulation;