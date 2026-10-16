library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.ALL;

entity mlp_memory is
    generic (
        DATA_WIDTH       : positive := 16;
        FRAC_BITS        : natural  := 9;
        N_INPUTS         : positive := 2;
        HIDDEN_NEURONS   : positive := 3;
        OUTPUT_NEURONS   : positive := 2;
        ACC_WIDTH        : positive := 40
    );
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;

        inputs : in STD_LOGIC_VECTOR(N_INPUTS*DATA_WIDTH-1 downto 0);

        -- External initialization writes: hidden layer
        hidden_weight_write_enable : in STD_LOGIC;
        hidden_weight_write_addr : in integer range 0 to N_INPUTS*HIDDEN_NEURONS-1;
        hidden_weight_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        hidden_bias_write_enable : in STD_LOGIC;
        hidden_bias_write_addr : in integer range 0 to HIDDEN_NEURONS-1;
        hidden_bias_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        -- External initialization writes: output layer
        output_weight_write_enable : in STD_LOGIC;
        output_weight_write_addr : in integer range 0 to HIDDEN_NEURONS*OUTPUT_NEURONS-1;
        output_weight_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        output_bias_write_enable : in STD_LOGIC;
        output_bias_write_addr : in integer range 0 to OUTPUT_NEURONS-1;
        output_bias_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        outputs : out STD_LOGIC_VECTOR(OUTPUT_NEURONS*DATA_WIDTH-1 downto 0);
        hidden_activations : out STD_LOGIC_VECTOR(HIDDEN_NEURONS*DATA_WIDTH-1 downto 0);

        -- Read port used by backpropagation to load output weights.
        output_weight_read_addr : in integer range 0 to HIDDEN_NEURONS*OUTPUT_NEURONS-1;
        output_weight_read_data : out SIGNED(DATA_WIDTH-1 downto 0);

        -- Unified hidden-layer parameter access for training updater.
        -- Addresses [0 .. N_INPUTS*HIDDEN_NEURONS-1] are weights,
        -- followed by biases.
        hidden_parameter_read_enable : in STD_LOGIC;
        hidden_parameter_read_address : in integer range
            0 to N_INPUTS*HIDDEN_NEURONS + HIDDEN_NEURONS - 1;
        hidden_parameter_read_data : out SIGNED(DATA_WIDTH-1 downto 0);
        hidden_parameter_write_enable : in STD_LOGIC;
        hidden_parameter_write_address : in integer range
            0 to N_INPUTS*HIDDEN_NEURONS + HIDDEN_NEURONS - 1;
        hidden_parameter_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        -- Unified output-layer parameter access for training updater.
        -- Addresses [0 .. HIDDEN_NEURONS*OUTPUT_NEURONS-1] are weights,
        -- followed by biases.
        output_parameter_read_enable : in STD_LOGIC;
        output_parameter_read_address : in integer range
            0 to HIDDEN_NEURONS*OUTPUT_NEURONS + OUTPUT_NEURONS - 1;
        output_parameter_read_data : out SIGNED(DATA_WIDTH-1 downto 0);
        output_parameter_write_enable : in STD_LOGIC;
        output_parameter_write_address : in integer range
            0 to HIDDEN_NEURONS*OUTPUT_NEURONS + OUTPUT_NEURONS - 1;
        output_parameter_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        busy : out STD_LOGIC;
        done : out STD_LOGIC
    );
end mlp_memory;

architecture Behavioral of mlp_memory is

    constant HIDDEN_WEIGHT_COUNT : positive := N_INPUTS*HIDDEN_NEURONS;
    constant HIDDEN_PARAMETER_COUNT : positive := HIDDEN_WEIGHT_COUNT + HIDDEN_NEURONS;
    constant OUTPUT_WEIGHT_COUNT : positive := HIDDEN_NEURONS*OUTPUT_NEURONS;
    constant OUTPUT_PARAMETER_COUNT : positive := OUTPUT_WEIGHT_COUNT + OUTPUT_NEURONS;

    type state_t is (IDLE, START_HIDDEN, WAIT_HIDDEN,
                     START_OUTPUT, WAIT_OUTPUT, FINISHED);
    signal state : state_t := IDLE;

    -- Inference read addresses/data (weight port A and bias read port).
    signal hidden_weight_read_addr : integer range 0 to HIDDEN_WEIGHT_COUNT-1 := 0;
    signal hidden_weight_read_data : SIGNED(DATA_WIDTH-1 downto 0);
    signal hidden_bias_read_addr_layer : integer range 0 to HIDDEN_NEURONS-1 := 0;
    signal hidden_bias_read_addr_mem : integer range 0 to HIDDEN_NEURONS-1 := 0;
    signal hidden_bias_read_data : SIGNED(DATA_WIDTH-1 downto 0);

    signal output_weight_read_addr_internal : integer range 0 to OUTPUT_WEIGHT_COUNT-1 := 0;
    signal output_weight_read_data_internal : SIGNED(DATA_WIDTH-1 downto 0);
    signal output_weight_read_addr_b_mem : integer range 0 to OUTPUT_WEIGHT_COUNT-1 := 0;
    signal output_weight_read_data_b_mem : SIGNED(DATA_WIDTH-1 downto 0);
    signal output_bias_read_addr_layer : integer range 0 to OUTPUT_NEURONS-1 := 0;
    signal output_bias_read_addr_mem : integer range 0 to OUTPUT_NEURONS-1 := 0;
    signal output_bias_read_data : SIGNED(DATA_WIDTH-1 downto 0);

    -- Weight-memory second-port signals for updater/backpropagation.
    signal hidden_weight_read_addr_b_mem : integer range 0 to HIDDEN_WEIGHT_COUNT-1 := 0;
    signal hidden_weight_read_data_b_mem : SIGNED(DATA_WIDTH-1 downto 0);

    -- Internal write buses with updater priority over initialization writes.
    signal hidden_weight_write_enable_mem : STD_LOGIC;
    signal hidden_weight_write_addr_mem : integer range 0 to HIDDEN_WEIGHT_COUNT-1 := 0;
    signal hidden_weight_write_data_mem : SIGNED(DATA_WIDTH-1 downto 0);
    signal hidden_bias_write_enable_mem : STD_LOGIC;
    signal hidden_bias_write_addr_mem : integer range 0 to HIDDEN_NEURONS-1 := 0;
    signal hidden_bias_write_data_mem : SIGNED(DATA_WIDTH-1 downto 0);

    signal output_weight_write_enable_mem : STD_LOGIC;
    signal output_weight_write_addr_mem : integer range 0 to OUTPUT_WEIGHT_COUNT-1 := 0;
    signal output_weight_write_data_mem : SIGNED(DATA_WIDTH-1 downto 0);
    signal output_bias_write_enable_mem : STD_LOGIC;
    signal output_bias_write_addr_mem : integer range 0 to OUTPUT_NEURONS-1 := 0;
    signal output_bias_write_data_mem : SIGNED(DATA_WIDTH-1 downto 0);

    signal hidden_outputs : STD_LOGIC_VECTOR(HIDDEN_NEURONS*DATA_WIDTH-1 downto 0);
    signal final_outputs : STD_LOGIC_VECTOR(OUTPUT_NEURONS*DATA_WIDTH-1 downto 0);

    signal hidden_start, hidden_busy, hidden_done : STD_LOGIC := '0';
    signal output_start, output_busy, output_done : STD_LOGIC := '0';

begin

    ------------------------------------------------------------------
    -- Give training writes priority over external initialization writes.
    ------------------------------------------------------------------
    hidden_weight_write_enable_mem <=
        '1' when hidden_parameter_write_enable = '1' and
                hidden_parameter_write_address < HIDDEN_WEIGHT_COUNT else
        '0' when hidden_parameter_write_enable = '1' else
        hidden_weight_write_enable;

    hidden_weight_write_addr_mem <=
        hidden_parameter_write_address when
            hidden_parameter_write_enable = '1' and
            hidden_parameter_write_address < HIDDEN_WEIGHT_COUNT else
        hidden_weight_write_addr;

    hidden_weight_write_data_mem <=
        hidden_parameter_write_data when hidden_parameter_write_enable = '1' else
        hidden_weight_write_data;

    hidden_bias_write_enable_mem <=
        '1' when hidden_parameter_write_enable = '1' and
                hidden_parameter_write_address >= HIDDEN_WEIGHT_COUNT else
        '0' when hidden_parameter_write_enable = '1' else
        hidden_bias_write_enable;

    hidden_bias_write_addr_mem <=
        hidden_parameter_write_address - HIDDEN_WEIGHT_COUNT when
            hidden_parameter_write_enable = '1' and
            hidden_parameter_write_address >= HIDDEN_WEIGHT_COUNT else
        hidden_bias_write_addr;

    hidden_bias_write_data_mem <=
        hidden_parameter_write_data when hidden_parameter_write_enable = '1' else
        hidden_bias_write_data;

    output_weight_write_enable_mem <=
        '1' when output_parameter_write_enable = '1' and
                output_parameter_write_address < OUTPUT_WEIGHT_COUNT else
        '0' when output_parameter_write_enable = '1' else
        output_weight_write_enable;

    output_weight_write_addr_mem <=
        output_parameter_write_address when
            output_parameter_write_enable = '1' and
            output_parameter_write_address < OUTPUT_WEIGHT_COUNT else
        output_weight_write_addr;

    output_weight_write_data_mem <=
        output_parameter_write_data when output_parameter_write_enable = '1' else
        output_weight_write_data;

    output_bias_write_enable_mem <=
        '1' when output_parameter_write_enable = '1' and
                output_parameter_write_address >= OUTPUT_WEIGHT_COUNT else
        '0' when output_parameter_write_enable = '1' else
        output_bias_write_enable;

    output_bias_write_addr_mem <=
        output_parameter_write_address - OUTPUT_WEIGHT_COUNT when
            output_parameter_write_enable = '1' and
            output_parameter_write_address >= OUTPUT_WEIGHT_COUNT else
        output_bias_write_addr;

    output_bias_write_data_mem <=
        output_parameter_write_data when output_parameter_write_enable = '1' else
        output_bias_write_data;

    ------------------------------------------------------------------
    -- Unified read address decoding for the hidden-layer updater.
    ------------------------------------------------------------------
    hidden_weight_read_addr_b_mem <=
        hidden_parameter_read_address when
            hidden_parameter_read_enable = '1' and
            hidden_parameter_read_address < HIDDEN_WEIGHT_COUNT else
        0;

    hidden_bias_read_addr_mem <=
        hidden_parameter_read_address - HIDDEN_WEIGHT_COUNT when
            hidden_parameter_read_enable = '1' and
            hidden_parameter_read_address >= HIDDEN_WEIGHT_COUNT else
        hidden_bias_read_addr_layer;

    hidden_parameter_read_data <=
        hidden_weight_read_data_b_mem when
            hidden_parameter_read_enable = '1' and
            hidden_parameter_read_address < HIDDEN_WEIGHT_COUNT else
        hidden_bias_read_data when hidden_parameter_read_enable = '1' else
        (others => '0');

    ------------------------------------------------------------------
    -- Unified read address decoding for the output-layer updater.
    -- The output weight-memory port B is shared with backpropagation;
    -- their accesses occur in different controller states.
    ------------------------------------------------------------------
    output_weight_read_addr_b_mem <=
        output_parameter_read_address when
            output_parameter_read_enable = '1' and
            output_parameter_read_address < OUTPUT_WEIGHT_COUNT else
        output_weight_read_addr;

    output_bias_read_addr_mem <=
        output_parameter_read_address - OUTPUT_WEIGHT_COUNT when
            output_parameter_read_enable = '1' and
            output_parameter_read_address >= OUTPUT_WEIGHT_COUNT else
        output_bias_read_addr_layer;

    output_parameter_read_data <=
        output_weight_read_data_b_mem when
            output_parameter_read_enable = '1' and
            output_parameter_read_address < OUTPUT_WEIGHT_COUNT else
        output_bias_read_data when output_parameter_read_enable = '1' else
        (others => '0');

    -- Expose the output weight value to the backpropagation loader.
    output_weight_read_data <= output_weight_read_data_b_mem;

    ------------------------------------------------------------------
    -- Hidden parameter memory
    ------------------------------------------------------------------
    HIDDEN_MEMORY : entity work.parameter_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => HIDDEN_WEIGHT_COUNT,
            N_BIASES   => HIDDEN_NEURONS
        )
        port map (
            clk => clk,

            weight_write_enable => hidden_weight_write_enable_mem,
            weight_write_addr   => hidden_weight_write_addr_mem,
            weight_write_data   => hidden_weight_write_data_mem,

            -- Port A: inference
            weight_read_addr  => hidden_weight_read_addr,
            weight_read_data  => hidden_weight_read_data,

            -- Port B: training parameter access
            weight_read_addr_b => hidden_weight_read_addr_b_mem,
            weight_read_data_b => hidden_weight_read_data_b_mem,

            bias_write_enable => hidden_bias_write_enable_mem,
            bias_write_addr   => hidden_bias_write_addr_mem,
            bias_write_data   => hidden_bias_write_data_mem,
            bias_read_addr    => hidden_bias_read_addr_mem,
            bias_read_data    => hidden_bias_read_data
        );

    ------------------------------------------------------------------
    -- Output parameter memory
    ------------------------------------------------------------------
    OUTPUT_MEMORY : entity work.parameter_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => OUTPUT_WEIGHT_COUNT,
            N_BIASES   => OUTPUT_NEURONS
        )
        port map (
            clk => clk,

            weight_write_enable => output_weight_write_enable_mem,
            weight_write_addr   => output_weight_write_addr_mem,
            weight_write_data   => output_weight_write_data_mem,

            -- Port A: inference
            weight_read_addr => output_weight_read_addr_internal,
            weight_read_data => output_weight_read_data_internal,

            -- Port B: backpropagation or output updater
            weight_read_addr_b => output_weight_read_addr_b_mem,
            weight_read_data_b => output_weight_read_data_b_mem,

            bias_write_enable => output_bias_write_enable_mem,
            bias_write_addr   => output_bias_write_addr_mem,
            bias_write_data   => output_bias_write_data_mem,
            bias_read_addr    => output_bias_read_addr_mem,
            bias_read_data    => output_bias_read_data
        );

    ------------------------------------------------------------------
    -- Hidden layer
    ------------------------------------------------------------------
    HIDDEN_LAYER : entity work.dense_layer_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            N_NEURONS  => HIDDEN_NEURONS,
            ACC_WIDTH  => ACC_WIDTH,
            ACTIVATION => RELU
        )
        port map (
            clk => clk,
            reset => reset,
            start => hidden_start,
            inputs => inputs,
            weight_read_addr => hidden_weight_read_addr,
            weight_read_data => hidden_weight_read_data,
            bias_read_addr => hidden_bias_read_addr_layer,
            bias_read_data => hidden_bias_read_data,
            outputs => hidden_outputs,
            busy => hidden_busy,
            done => hidden_done
        );

    ------------------------------------------------------------------
    -- Output layer
    ------------------------------------------------------------------
    OUTPUT_LAYER : entity work.dense_layer_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => HIDDEN_NEURONS,
            N_NEURONS  => OUTPUT_NEURONS,
            ACC_WIDTH  => ACC_WIDTH,
            ACTIVATION => LINEAR
        )
        port map (
            clk => clk,
            reset => reset,
            start => output_start,
            inputs => hidden_outputs,
            weight_read_addr => output_weight_read_addr_internal,
            weight_read_data => output_weight_read_data_internal,
            bias_read_addr => output_bias_read_addr_layer,
            bias_read_data => output_bias_read_data,
            outputs => final_outputs,
            busy => output_busy,
            done => output_done
        );

    ------------------------------------------------------------------
    -- Inference controller
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if start = '1' then
                        state <= START_HIDDEN;
                    end if;

                when START_HIDDEN =>
                    state <= WAIT_HIDDEN;

                when WAIT_HIDDEN =>
                    if hidden_done = '1' then
                        state <= START_OUTPUT;
                    end if;

                when START_OUTPUT =>
                    state <= WAIT_OUTPUT;

                when WAIT_OUTPUT =>
                    if output_done = '1' then
                        state <= FINISHED;
                    end if;

                when FINISHED =>
                    if start = '0' then
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    hidden_start <= '1' when state = START_HIDDEN else '0';
    output_start <= '1' when state = START_OUTPUT else '0';

    outputs <= final_outputs;
    hidden_activations <= hidden_outputs;

    busy <= '1' when state = START_HIDDEN or state = WAIT_HIDDEN or
                     state = START_OUTPUT or state = WAIT_OUTPUT
            else '0';

    done <= '1' when state = FINISHED else '0';

end Behavioral;
