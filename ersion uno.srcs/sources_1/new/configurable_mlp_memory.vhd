library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.ALL;

entity configurable_mlp_memory is
    generic (
        DATA_WIDTH  : positive := 16;
        FRAC_BITS   : natural := 9;
        LAYER_SIZES : positive_array_t := (2, 3, 2);
        ACC_WIDTH   : positive := 40
    );
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;

        inputs : in STD_LOGIC_VECTOR(
            LAYER_SIZES(LAYER_SIZES'low) * DATA_WIDTH - 1 downto 0
        );

        init_parameter_write_enable : in STD_LOGIC;
        init_parameter_write_address : in integer range
            0 to network_parameter_count(LAYER_SIZES) - 1;
        init_parameter_write_data : in SIGNED(DATA_WIDTH - 1 downto 0);

        parameter_read_address : in integer range
            0 to network_parameter_count(LAYER_SIZES) - 1;
        parameter_read_data : out SIGNED(DATA_WIDTH - 1 downto 0);

        parameter_write_enable : in STD_LOGIC;
        parameter_write_address : in integer range
            0 to network_parameter_count(LAYER_SIZES) - 1;
        parameter_write_data : in SIGNED(DATA_WIDTH - 1 downto 0);

        predictions : out STD_LOGIC_VECTOR(
            LAYER_SIZES(LAYER_SIZES'high) * DATA_WIDTH - 1 downto 0
        );

        all_activations : out STD_LOGIC_VECTOR(
            network_activation_count(LAYER_SIZES) * DATA_WIDTH - 1 downto 0
        );

        all_weights : out STD_LOGIC_VECTOR(
            network_weight_count(LAYER_SIZES) * DATA_WIDTH - 1 downto 0
        );

        busy : out STD_LOGIC;
        done : out STD_LOGIC
    );
end entity configurable_mlp_memory;


architecture Behavioral of configurable_mlp_memory is

    constant LAYER_COUNT : positive :=
        LAYER_SIZES'length;

    constant DENSE_LAYER_COUNT : positive :=
        LAYER_COUNT - 1;

    constant TOTAL_WEIGHTS : positive :=
        network_weight_count(LAYER_SIZES);

    constant TOTAL_BIASES : positive :=
        network_bias_count(LAYER_SIZES);

    constant TOTAL_PARAMETERS : positive :=
        network_parameter_count(LAYER_SIZES);

    constant TOTAL_ACTIVATIONS : positive :=
        network_activation_count(LAYER_SIZES);

    -- First weight belonging to the final output layer.
    -- For (2, 4, 4, 2), this is address 24.
    constant OUTPUT_WEIGHT_START : natural :=
        TOTAL_WEIGHTS -
        LAYER_SIZES(LAYER_SIZES'high - 1) *
        LAYER_SIZES(LAYER_SIZES'high);

    -- One-time diagnostic flags.
    signal first_hidden_weight_update_reported : boolean := false;
    signal output_weight_update_reported       : boolean := false;


    type parameter_array_t is array (natural range <>) of
        SIGNED(DATA_WIDTH - 1 downto 0);

    type integer_array_t is array (natural range <>) of integer;

    type state_t is (
        IDLE,
        START_LAYER,
        WAIT_LAYER,
        FINISHED
    );

    signal state : state_t := IDLE;

    signal active_layer : integer range
        0 to DENSE_LAYER_COUNT - 1 := 0;


    ----------------------------------------------------------------
    -- Unified parameter storage
    ----------------------------------------------------------------
    signal weights_mem : parameter_array_t(
        0 to TOTAL_WEIGHTS - 1
    ) := (others => (others => '0'));

    signal biases_mem : parameter_array_t(
        0 to TOTAL_BIASES - 1
    ) := (others => (others => '0'));


    ----------------------------------------------------------------
    -- Packed activation storage
    ----------------------------------------------------------------
    signal activation_bus : STD_LOGIC_VECTOR(
        TOTAL_ACTIVATIONS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');


    ----------------------------------------------------------------
    -- Per-layer control and parameter-read interfaces
    ----------------------------------------------------------------
    signal layer_start : STD_LOGIC_VECTOR(
        0 to DENSE_LAYER_COUNT - 1
    ) := (others => '0');

    signal layer_busy : STD_LOGIC_VECTOR(
        0 to DENSE_LAYER_COUNT - 1
    );

    signal layer_done : STD_LOGIC_VECTOR(
        0 to DENSE_LAYER_COUNT - 1
    );

    signal layer_weight_read_addr : integer_array_t(
        0 to DENSE_LAYER_COUNT - 1
    );

    signal layer_bias_read_addr : integer_array_t(
        0 to DENSE_LAYER_COUNT - 1
    );

    signal layer_weight_read_data : parameter_array_t(
        0 to DENSE_LAYER_COUNT - 1
    );

    signal layer_bias_read_data : parameter_array_t(
        0 to DENSE_LAYER_COUNT - 1
    );


    ----------------------------------------------------------------
    -- Activation offset, measured in neurons
    ----------------------------------------------------------------
    function activation_offset(
        sizes : positive_array_t;
        layer_index : natural
    ) return natural is
        variable total : natural := 0;
    begin
        if layer_index > 0 then
            for k in sizes'low to
                     sizes'low + layer_index - 1 loop
                total := total + sizes(k);
            end loop;
        end if;

        return total;
    end function;


    ----------------------------------------------------------------
    -- Weight offset for a dense layer
    ----------------------------------------------------------------
    function weight_offset(
        sizes : positive_array_t;
        layer_index : natural
    ) return natural is
        variable total : natural := 0;
    begin
        if layer_index > 0 then
            for k in sizes'low to
                     sizes'low + layer_index - 1 loop
                total := total + sizes(k) * sizes(k + 1);
            end loop;
        end if;

        return total;
    end function;


    ----------------------------------------------------------------
    -- Bias offset for a dense layer
    ----------------------------------------------------------------
    function bias_offset(
        sizes : positive_array_t;
        dense_index : natural
    ) return natural is
        variable total : natural := 0;
    begin
        if dense_index > 0 then
            for k in sizes'low + 1 to
                     sizes'low + dense_index loop
                total := total + sizes(k);
            end loop;
        end if;

        return total;
    end function;


begin

    ----------------------------------------------------------------
    -- Export all weights as a packed vector
    ----------------------------------------------------------------
    WEIGHT_PACKING : for k in 0 to TOTAL_WEIGHTS - 1 generate
    begin
        all_weights(
            (k + 1) * DATA_WIDTH - 1 downto k * DATA_WIDTH
        ) <= STD_LOGIC_VECTOR(weights_mem(k));
    end generate WEIGHT_PACKING;


    ----------------------------------------------------------------
    -- Validate network shape
    ----------------------------------------------------------------
    assert LAYER_COUNT >= 2
        report "LAYER_SIZES must contain at least two entries"
        severity failure;


    ----------------------------------------------------------------
    -- Input layer occupies the first activation slice
    ----------------------------------------------------------------
    activation_bus(
        LAYER_SIZES(LAYER_SIZES'low) * DATA_WIDTH - 1 downto 0
    ) <= inputs;


    ----------------------------------------------------------------
    -- Unified asynchronous parameter read port
    ----------------------------------------------------------------
    parameter_read_data <=
        weights_mem(parameter_read_address)
        when parameter_read_address < TOTAL_WEIGHTS
        else biases_mem(
            parameter_read_address - TOTAL_WEIGHTS
        );


    ----------------------------------------------------------------
    -- Parameter write process
    --
    -- Training updates have priority over initialization writes.
    -- Reset does not erase stored parameters.
    --
    -- Diagnostics:
    -- 1. First hidden-layer weight, address 0.
    -- 2. First output-layer weight, address OUTPUT_WEIGHT_START.
    ----------------------------------------------------------------
    PARAMETER_WRITE_PROCESS : process(clk)

        variable selected_address : integer range
            0 to TOTAL_PARAMETERS - 1;

        variable selected_data : SIGNED(DATA_WIDTH - 1 downto 0);

        variable selected_write : boolean;

    begin
        if rising_edge(clk) then

            -- Reset the diagnostic flags.
            if reset = '1' then
                first_hidden_weight_update_reported <= false;
                output_weight_update_reported       <= false;
            end if;

            selected_write := false;
            selected_address := 0;
            selected_data := (others => '0');

            if reset = '0' then

                if parameter_write_enable = '1' then
                    selected_address := parameter_write_address;
                    selected_data := parameter_write_data;
                    selected_write := true;

                elsif init_parameter_write_enable = '1' then
                    selected_address := init_parameter_write_address;
                    selected_data := init_parameter_write_data;
                    selected_write := true;
                end if;

                if selected_write then

                    ------------------------------------------------
                    -- Write to weight memory
                    ------------------------------------------------
                    if selected_address < TOTAL_WEIGHTS then

                        -- Check the first hidden-layer weight.
                        -- Initialization writes are excluded.
                        if parameter_write_enable = '1' and
                           selected_address = 0 and
                           not first_hidden_weight_update_reported then

                            report
                                "HIDDEN UPDATE CHECK: weight 0" &
                                ", address=" &
                                integer'image(selected_address) &
                                ", old=" &
                                integer'image(
                                    to_integer(weights_mem(0))
                                ) &
                                ", new=" &
                                integer'image(
                                    to_integer(selected_data)
                                )
                                severity note;

                            first_hidden_weight_update_reported <= true;
                        end if;


                        -- Check the first output-layer weight.
                        -- Initialization writes are excluded.
                        if parameter_write_enable = '1' and
                           selected_address = OUTPUT_WEIGHT_START and
                           not output_weight_update_reported then

                            report
                                "UPDATE CHECK: output weight 0" &
                                ", address=" &
                                integer'image(selected_address) &
                                ", old=" &
                                integer'image(
                                    to_integer(
                                        weights_mem(selected_address)
                                    )
                                ) &
                                ", new=" &
                                integer'image(
                                    to_integer(selected_data)
                                )
                                severity note;

                            output_weight_update_reported <= true;
                        end if;


                        -- Perform the actual weight write.
                        weights_mem(selected_address) <= selected_data;


                    ------------------------------------------------
                    -- Write to bias memory
                    ------------------------------------------------
                    else
                        biases_mem(
                            selected_address - TOTAL_WEIGHTS
                        ) <= selected_data;
                    end if;

                end if;
            end if;
        end if;
    end process PARAMETER_WRITE_PROCESS;


    ----------------------------------------------------------------
    -- Automatically instantiate every dense layer
    --
    -- Hidden layers use ReLU.
    -- The final output layer uses linear activation.
    ----------------------------------------------------------------
    LAYER_GENERATION :
    for g in 0 to DENSE_LAYER_COUNT - 1 generate

        constant INPUT_LAYER_INDEX : natural :=
            LAYER_SIZES'low + g;

        constant OUTPUT_LAYER_INDEX : natural :=
            LAYER_SIZES'low + g + 1;

        constant INPUT_OFFSET : natural :=
            activation_offset(LAYER_SIZES, g);

        constant OUTPUT_OFFSET : natural :=
            activation_offset(LAYER_SIZES, g + 1);

        constant WEIGHT_START : natural :=
            weight_offset(LAYER_SIZES, g);

        constant BIAS_START : natural :=
            bias_offset(LAYER_SIZES, g);

    begin

        ------------------------------------------------------------
        -- Select this layer's weights and biases
        ------------------------------------------------------------
        layer_weight_read_data(g) <=
            weights_mem(
                WEIGHT_START + layer_weight_read_addr(g)
            );

        layer_bias_read_data(g) <=
            biases_mem(
                BIAS_START + layer_bias_read_addr(g)
            );


        ------------------------------------------------------------
        -- Start only the selected layer
        ------------------------------------------------------------
        layer_start(g) <= '1'
            when state = START_LAYER and active_layer = g
            else '0';


        ------------------------------------------------------------
        -- Hidden layers: ReLU
        ------------------------------------------------------------
        HIDDEN_LAYER :
        if g < DENSE_LAYER_COUNT - 1 generate

            DENSE : entity work.dense_layer_memory
                generic map (
                    DATA_WIDTH => DATA_WIDTH,
                    FRAC_BITS  => FRAC_BITS,
                    N_INPUTS   => LAYER_SIZES(INPUT_LAYER_INDEX),
                    N_NEURONS  => LAYER_SIZES(OUTPUT_LAYER_INDEX),
                    ACC_WIDTH  => ACC_WIDTH,
                    ACTIVATION => RELU
                )
                port map (
                    clk   => clk,
                    reset => reset,
                    start => layer_start(g),

                    inputs => activation_bus(
                        (OUTPUT_OFFSET * DATA_WIDTH) - 1 downto
                        INPUT_OFFSET * DATA_WIDTH
                    ),

                    weight_read_addr => layer_weight_read_addr(g),
                    weight_read_data => layer_weight_read_data(g),

                    bias_read_addr => layer_bias_read_addr(g),
                    bias_read_data => layer_bias_read_data(g),

                    outputs => activation_bus(
                        (OUTPUT_OFFSET +
                         LAYER_SIZES(OUTPUT_LAYER_INDEX)) *
                         DATA_WIDTH - 1 downto
                        OUTPUT_OFFSET * DATA_WIDTH
                    ),

                    busy => layer_busy(g),
                    done => layer_done(g)
                );

        end generate HIDDEN_LAYER;


        ------------------------------------------------------------
        -- Final output layer: linear activation
        ------------------------------------------------------------
        OUTPUT_LAYER :
        if g = DENSE_LAYER_COUNT - 1 generate

            DENSE : entity work.dense_layer_memory
                generic map (
                    DATA_WIDTH => DATA_WIDTH,
                    FRAC_BITS  => FRAC_BITS,
                    N_INPUTS   => LAYER_SIZES(INPUT_LAYER_INDEX),
                    N_NEURONS  => LAYER_SIZES(OUTPUT_LAYER_INDEX),
                    ACC_WIDTH  => ACC_WIDTH,
                    ACTIVATION => LINEAR
                )
                port map (
                    clk   => clk,
                    reset => reset,
                    start => layer_start(g),

                    inputs => activation_bus(
                        (OUTPUT_OFFSET * DATA_WIDTH) - 1 downto
                        INPUT_OFFSET * DATA_WIDTH
                    ),

                    weight_read_addr => layer_weight_read_addr(g),
                    weight_read_data => layer_weight_read_data(g),

                    bias_read_addr => layer_bias_read_addr(g),
                    bias_read_data => layer_bias_read_data(g),

                    outputs => activation_bus(
                        (OUTPUT_OFFSET +
                         LAYER_SIZES(OUTPUT_LAYER_INDEX)) *
                         DATA_WIDTH - 1 downto
                        OUTPUT_OFFSET * DATA_WIDTH
                    ),

                    busy => layer_busy(g),
                    done => layer_done(g)
                );

        end generate OUTPUT_LAYER;

    end generate LAYER_GENERATION;


    ----------------------------------------------------------------
    -- Inference controller: execute layers in order
    ----------------------------------------------------------------
    INFERENCE_CONTROLLER : process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            active_layer <= 0;

        elsif rising_edge(clk) then

            case state is

                when IDLE =>
                    active_layer <= 0;

                    if start = '1' then
                        state <= START_LAYER;
                    end if;


                when START_LAYER =>
                    -- The selected dense layer samples its start pulse.
                    state <= WAIT_LAYER;


                when WAIT_LAYER =>
                    if layer_done(active_layer) = '1' then

                        if active_layer = DENSE_LAYER_COUNT - 1 then
                            state <= FINISHED;
                        else
                            active_layer <= active_layer + 1;
                            state <= START_LAYER;
                        end if;

                    end if;


                when FINISHED =>
                    -- Require start to go low before another run.
                    if start = '0' then
                        state <= IDLE;
                    end if;


                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process INFERENCE_CONTROLLER;


    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------
    predictions <= activation_bus(
        (TOTAL_ACTIVATIONS * DATA_WIDTH) - 1 downto
        (TOTAL_ACTIVATIONS -
         LAYER_SIZES(LAYER_SIZES'high)) * DATA_WIDTH
    );

    all_activations <= activation_bus;

    busy <= '1'
        when state = START_LAYER or state = WAIT_LAYER
        else '0';

    done <= '1' when state = FINISHED else '0';

end architecture Behavioral;