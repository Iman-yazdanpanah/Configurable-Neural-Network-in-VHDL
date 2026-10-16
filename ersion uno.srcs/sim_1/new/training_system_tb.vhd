library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.ALL;

entity training_system_tb is
end training_system_tb;

architecture Behavioral of training_system_tb is

    ----------------------------------------------------------------
    -- CONFIGURATION
    ----------------------------------------------------------------
    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant ACC_WIDTH  : positive := 40;
    constant GRAD_WIDTH : positive := 32;

    -- Network: 2 inputs -> 4 -> 4 -> 2 outputs
    constant LAYER_SIZES : positive_array_t := (2, 4, 4, 2);

    constant TOTAL_WEIGHTS : positive :=
        network_weight_count(LAYER_SIZES);

    constant TOTAL_PARAMETERS : positive :=
        network_parameter_count(LAYER_SIZES);

    constant TOTAL_ACTIVATIONS : positive :=
        network_activation_count(LAYER_SIZES);

    -- First weight in the output layer.
    -- Weight indices: 0..7, 8..23, 24..31.
    constant OUTPUT_WEIGHT_START : natural :=
        TOTAL_WEIGHTS -
        LAYER_SIZES(LAYER_SIZES'high - 1) *
        LAYER_SIZES(LAYER_SIZES'high);

    constant MAX_EPOCHS  : positive := 50;
    constant ERROR_LIMIT : natural  := 512;

    type int_array_t is array (natural range <>) of integer;

    ----------------------------------------------------------------
    -- INITIAL WEIGHTS
    -- Q9: 512 = 1.0, 256 = 0.5
    ----------------------------------------------------------------
    constant INITIAL_WEIGHTS :
        int_array_t(0 to TOTAL_WEIGHTS-1) := (

        -- Layer 1: 2 inputs -> 4 neurons
        512,    0,
          0,  512,
        512,  512,
        512, -512,

        -- Layer 2: 4 -> 4 (identity matrix)
        512, 0,   0,   0,
          0, 512, 0,   0,
          0, 0,   512, 0,
          0, 0,   0,   512,

        -- Output layer: 4 -> 2
        256, 256, 256, 256,
        256, 256, 256, 256
    );

    ----------------------------------------------------------------
    -- INITIAL BIASES
    ----------------------------------------------------------------
    constant INITIAL_BIASES :
        int_array_t(0 to TOTAL_PARAMETERS-TOTAL_WEIGHTS-1) :=
        (
            -- First hidden layer
            0, 0, 0, 256,

            -- Second hidden layer
            0, 0, 0, 0,

            -- Output layer
            0, 0
        );

    ----------------------------------------------------------------
    -- SIGNALS
    ----------------------------------------------------------------
    signal clk          : STD_LOGIC := '0';
    signal reset        : STD_LOGIC := '1';
    signal start        : STD_LOGIC := '0';
    signal train_enable : STD_LOGIC := '1';
    signal stop_clock   : boolean := false;

    signal inputs : STD_LOGIC_VECTOR(
        LAYER_SIZES(LAYER_SIZES'low)*DATA_WIDTH-1 downto 0
    ) := (others => '0');

    signal targets : STD_LOGIC_VECTOR(
        LAYER_SIZES(LAYER_SIZES'high)*DATA_WIDTH-1 downto 0
    ) := (others => '0');

    -- Q9 learning rate: raw 1 = 1/512.
    signal learning_rate : SIGNED(DATA_WIDTH-1 downto 0) :=
        to_signed(2, DATA_WIDTH);

    signal init_parameter_write_enable : STD_LOGIC := '0';

    signal init_parameter_write_address : integer range
        0 to TOTAL_PARAMETERS-1 := 0;

    signal init_parameter_write_data :
        SIGNED(DATA_WIDTH-1 downto 0) := (others => '0');

    signal predictions : STD_LOGIC_VECTOR(
        LAYER_SIZES(LAYER_SIZES'high)*DATA_WIDTH-1 downto 0
    );

    signal all_activations : STD_LOGIC_VECTOR(
        TOTAL_ACTIVATIONS*DATA_WIDTH-1 downto 0
    );

    signal all_deltas : STD_LOGIC_VECTOR(
        TOTAL_ACTIVATIONS*DATA_WIDTH-1 downto 0
    );

    signal gradients : STD_LOGIC_VECTOR(
        TOTAL_PARAMETERS*GRAD_WIDTH-1 downto 0
    );

    signal busy : STD_LOGIC;
    signal done : STD_LOGIC;

begin

    ----------------------------------------------------------------
    -- CLOCK GENERATION: 10 ns period
    ----------------------------------------------------------------
    clock_process : process
    begin
        while not stop_clock loop
            clk <= '0';
            wait for 5 ns;

            clk <= '1';
            wait for 5 ns;
        end loop;

        wait;
    end process;


    ----------------------------------------------------------------
    -- DEVICE UNDER TEST
    ----------------------------------------------------------------
    DUT : entity work.training_system
        generic map (
            DATA_WIDTH  => DATA_WIDTH,
            FRAC_BITS   => FRAC_BITS,
            LAYER_SIZES => LAYER_SIZES,
            ACC_WIDTH   => ACC_WIDTH,
            GRAD_WIDTH  => GRAD_WIDTH
        )
        port map (
            clk   => clk,
            reset => reset,
            start => start,
            train_enable => train_enable,

            inputs        => inputs,
            targets       => targets,
            learning_rate => learning_rate,

            init_parameter_write_enable =>
                init_parameter_write_enable,

            init_parameter_write_address =>
                init_parameter_write_address,

            init_parameter_write_data =>
                init_parameter_write_data,

            predictions     => predictions,
            all_activations => all_activations,
            all_deltas      => all_deltas,
            gradients       => gradients,

            busy => busy,
            done => done
        );


    ----------------------------------------------------------------
    -- TEST STIMULUS
    ----------------------------------------------------------------
    stimulus : process

        variable sample_error      : integer := 0;
        variable epoch_error       : integer := 0;
        variable evaluation_error  : integer := 0;
        variable epochs_run        : integer := 0;

        -- Ensure the gradient diagnostic is reported only once.
        variable gradient_reported : boolean := false;

        ------------------------------------------------------------
        -- WRITE ONE PARAMETER
        ------------------------------------------------------------
        procedure write_parameter(
            constant address : in integer;
            constant value   : in integer
        ) is
        begin
            wait until falling_edge(clk);

            init_parameter_write_enable <= '1';
            init_parameter_write_address <= address;
            init_parameter_write_data <=
                to_signed(value, DATA_WIDTH);

            wait until rising_edge(clk);
        end procedure;


        ------------------------------------------------------------
        -- RUN ONE TRAINING OR INFERENCE SAMPLE
        ------------------------------------------------------------
        procedure run_sample(
            constant x0_raw        : in integer;
            constant x1_raw        : in integer;
            constant target_raw    : in integer;
            constant training_mode : in STD_LOGIC;
            variable error_raw     : out integer
        ) is
            variable got_done        : boolean := false;
            variable pred0_raw       : integer := 0;
            variable pred1_raw       : integer := 0;
            variable error_sum_local : integer := 0;
            variable gradient_raw    : integer := 0;
        begin

            -- Input 0 occupies the least-significant slice.
            inputs <=
                std_logic_vector(to_signed(x1_raw, DATA_WIDTH)) &
                std_logic_vector(to_signed(x0_raw, DATA_WIDTH));

            -- Both output neurons use the same target.
            targets <=
                std_logic_vector(to_signed(target_raw, DATA_WIDTH)) &
                std_logic_vector(to_signed(target_raw, DATA_WIDTH));

            train_enable <= training_mode;

            -- Start pulse.
            wait until falling_edge(clk);
            start <= '1';

            wait until falling_edge(clk);
            start <= '0';

            -- Wait for completion, with a timeout.
            got_done := false;

            for timeout_count in 0 to 1000 loop
                wait until rising_edge(clk);
                wait for 1 ns;

                if done = '1' then
                    got_done := true;
                    exit;
                end if;
            end loop;

            assert got_done
                report "TIMEOUT: training_system did not assert done."
                severity failure;

            -- Extract the signed Q9 predictions.
            pred0_raw := to_integer(
                signed(predictions(DATA_WIDTH-1 downto 0))
            );

            pred1_raw := to_integer(
                signed(
                    predictions(2*DATA_WIDTH-1 downto DATA_WIDTH)
                )
            );

            --------------------------------------------------------
            -- GRADIENT DIAGNOSTIC
            --
            -- The first output-layer weight has parameter index 24.
            -- Expected initial gradient for sample (1,2) -> 2:
            -- approximately 1024 in raw Q9 format.
            --------------------------------------------------------
            if training_mode = '1' and
               not gradient_reported then

                gradient_raw := to_integer(
                    signed(
                        gradients(
                            (OUTPUT_WEIGHT_START + 1) * GRAD_WIDTH - 1
                            downto OUTPUT_WEIGHT_START * GRAD_WIDTH
                        )
                    )
                );
                report
                    "GRADIENT CHECK: first hidden weight 0 = " &
                    integer'image(
                        to_integer(
                            signed(gradients(GRAD_WIDTH-1 downto 0))
                        )
                    ) &
                    " (raw Q9; expected approximately 1024)"
                    severity note;
                report
                    "GRADIENT CHECK: output weight 0 = " &
                    integer'image(gradient_raw) &
                    " (raw Q9; expected approximately 1024)"
                    severity note;
                for k in 0 to 7 loop
                    report
                        "HIDDEN WEIGHT GRADIENT " & integer'image(k) & " = " &
                        integer'image(
                            to_integer(
                                signed(
                                    gradients(
                                        (k + 1) * GRAD_WIDTH - 1 downto
                                        k * GRAD_WIDTH
                                    )
                                )
                            )
                        )
                        severity note;
                end loop;
                gradient_reported := true;
            end if;

            -- Total absolute error for both outputs.
            error_sum_local :=
                abs(pred0_raw - target_raw) +
                abs(pred1_raw - target_raw);

            error_raw := error_sum_local;

            if training_mode = '1' then
                report
                    "TRAIN: x0=" & integer'image(x0_raw) &
                    ", x1=" & integer'image(x1_raw) &
                    ", target=" & integer'image(target_raw) &
                    ", pred0=" & integer'image(pred0_raw) &
                    ", pred1=" & integer'image(pred1_raw) &
                    ", error_raw_Q9=" &
                    integer'image(error_sum_local)
                    severity note;
            else
                report
                    "EVAL: x0=" & integer'image(x0_raw) &
                    ", x1=" & integer'image(x1_raw) &
                    ", target=" & integer'image(target_raw) &
                    ", pred0=" & integer'image(pred0_raw) &
                    ", pred1=" & integer'image(pred1_raw) &
                    ", error_raw_Q9=" &
                    integer'image(error_sum_local)
                    severity note;
            end if;

            -- Let the controller return to IDLE before restarting.
            wait until falling_edge(clk);
            wait until rising_edge(clk);
            wait for 1 ns;

        end procedure;


    begin

        ------------------------------------------------------------
        -- 1. RESET
        ------------------------------------------------------------
        reset <= '1';
        start <= '0';
        init_parameter_write_enable <= '0';

        wait for 40 ns;
        wait until falling_edge(clk);

        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;


        ------------------------------------------------------------
        -- 2. INITIALIZE ALL WEIGHTS
        ------------------------------------------------------------
        report "Initializing network weights." severity note;

        for i in 0 to TOTAL_WEIGHTS-1 loop
            write_parameter(i, INITIAL_WEIGHTS(i));
        end loop;


        ------------------------------------------------------------
        -- 3. INITIALIZE ALL BIASES
        ------------------------------------------------------------
        report "Initializing network biases." severity note;

        for i in 0 to INITIAL_BIASES'length-1 loop
            write_parameter(
                TOTAL_WEIGHTS + i,
                INITIAL_BIASES(i)
            );
        end loop;

        wait until falling_edge(clk);
        init_parameter_write_enable <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        report
            "Parameter initialization complete. " &
            "Weights=" & integer'image(TOTAL_WEIGHTS) &
            ", parameters=" & integer'image(TOTAL_PARAMETERS)
            severity note;


        ------------------------------------------------------------
        -- 4. TRAINING AND POST-UPDATE EVALUATION
        ------------------------------------------------------------
        for epoch in 1 to MAX_EPOCHS loop

            epoch_error := 0;

            -- Training sample 1: (1,2) -> 2
            run_sample(
                512, 1024, 1024, '1', sample_error
            );

            epoch_error := epoch_error + sample_error;


            -- Training sample 2: (2,2) -> 4
            run_sample(
                1024, 1024, 2048, '1', sample_error
            );

            epoch_error := epoch_error + sample_error;


            -- Training sample 3: (2,3) -> 6
            run_sample(
                1024, 1536, 3072, '1', sample_error
            );

            epoch_error := epoch_error + sample_error;

            epochs_run := epoch;

            report
                "EPOCH=" & integer'image(epoch) &
                ", training_error_raw_Q9=" &
                integer'image(epoch_error)
                severity note;


            --------------------------------------------------------
            -- POST-UPDATE EVALUATION: NO PARAMETER UPDATES
            --------------------------------------------------------
            evaluation_error := 0;

            run_sample(
                512, 1024, 1024, '0', sample_error
            );

            evaluation_error :=
                evaluation_error + sample_error;


            run_sample(
                1024, 1024, 2048, '0', sample_error
            );

            evaluation_error :=
                evaluation_error + sample_error;


            run_sample(
                1024, 1536, 3072, '0', sample_error
            );

            evaluation_error :=
                evaluation_error + sample_error;


            report
                "EPOCH=" & integer'image(epoch) &
                ", post_update_error_raw_Q9=" &
                integer'image(evaluation_error) &
                ", error_limit=" & integer'image(ERROR_LIMIT)
                severity note;

            if evaluation_error <= ERROR_LIMIT then
                report
                    "Stopping: post-update evaluation reached the error limit."
                    severity note;

                exit;
            end if;

        end loop;


        ------------------------------------------------------------
        -- 5. FINAL INFERENCE TEST: (1,3) -> 3
        ------------------------------------------------------------
        report "Starting final inference-only test." severity note;

        run_sample(
            512, 1536, 1536, '0', sample_error
        );

        report
            "Final inference error raw Q9=" &
            integer'image(sample_error)
            severity note;


        ------------------------------------------------------------
        -- 6. END SIMULATION
        ------------------------------------------------------------
        report
            "Training finished. Epochs completed=" &
            integer'image(epochs_run)
            severity note;

        wait for 20 ns;

        report "Simulation completed." severity note;

        stop_clock <= true;
        wait;

    end process;

end Behavioral;