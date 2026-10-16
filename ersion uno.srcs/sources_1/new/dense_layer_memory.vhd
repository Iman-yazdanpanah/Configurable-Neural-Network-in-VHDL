
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.nn_types.ALL;

entity dense_layer_memory is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_INPUTS   : positive := 2;
        N_NEURONS  : positive := 2;
        ACC_WIDTH  : positive := 40;
        ACTIVATION : activation_t := RELU
    );
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;

        -- Packed input values
        inputs : in STD_LOGIC_VECTOR(
            N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        -- Parameter memory read interface
        weight_read_addr : out integer range
            0 to (N_INPUTS * N_NEURONS) - 1;
        weight_read_data : in SIGNED(DATA_WIDTH - 1 downto 0);

        bias_read_addr : out integer range
            0 to N_NEURONS - 1;
        bias_read_data : in SIGNED(DATA_WIDTH - 1 downto 0);

        -- Layer output and status
        outputs : out STD_LOGIC_VECTOR(
            N_NEURONS * DATA_WIDTH - 1 downto 0
        );
        busy : out STD_LOGIC;
        done : out STD_LOGIC
    );
end dense_layer_memory;

architecture Behavioral of dense_layer_memory is

    constant N_WEIGHTS : positive := N_INPUTS * N_NEURONS;

    type state_t is (
        IDLE,
        LOAD_WEIGHTS,
        LOAD_BIASES,
        READY
    );

    signal state : state_t := IDLE;

    signal weight_count : integer range 0 to N_WEIGHTS - 1 := 0;
    signal bias_count   : integer range 0 to N_NEURONS - 1 := 0;

    signal weights_reg : STD_LOGIC_VECTOR(
        N_WEIGHTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal biases_reg : STD_LOGIC_VECTOR(
        N_NEURONS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal layer_outputs : STD_LOGIC_VECTOR(
        N_NEURONS * DATA_WIDTH - 1 downto 0
    );

begin

    ----------------------------------------------------------------
    -- Read parameters one at a time and assemble packed vectors.
    ----------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state        <= IDLE;
            weight_count <= 0;
            bias_count   <= 0;
            weights_reg  <= (others => '0');
            biases_reg   <= (others => '0');

        elsif rising_edge(clk) then

            case state is

                when IDLE =>
                    weight_count <= 0;
                    bias_count   <= 0;

                    if start = '1' then
                        state <= LOAD_WEIGHTS;
                    end if;

                when LOAD_WEIGHTS =>
                    -- The memory has asynchronous read outputs.
                    -- Capture the value at the current address.
                    weights_reg(
                        (weight_count + 1) * DATA_WIDTH - 1
                        downto weight_count * DATA_WIDTH
                    ) <= STD_LOGIC_VECTOR(weight_read_data);

                    if weight_count = N_WEIGHTS - 1 then
                        bias_count <= 0;
                        state      <= LOAD_BIASES;
                    else
                        weight_count <= weight_count + 1;
                    end if;

                when LOAD_BIASES =>
                    biases_reg(
                        (bias_count + 1) * DATA_WIDTH - 1
                        downto bias_count * DATA_WIDTH
                    ) <= STD_LOGIC_VECTOR(bias_read_data);

                    if bias_count = N_NEURONS - 1 then
                        state <= READY;
                    else
                        bias_count <= bias_count + 1;
                    end if;

                when READY =>
                    -- Hold the loaded parameters until a new
                    -- operation is requested after start goes low.
                    if start = '0' then
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Memory addresses
    ----------------------------------------------------------------
    weight_read_addr <= weight_count;
    bias_read_addr   <= bias_count;

    ----------------------------------------------------------------
    -- Existing combinational dense layer
    ----------------------------------------------------------------
    DENSE : entity work.dense_layer
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            N_NEURONS  => N_NEURONS,
            ACC_WIDTH  => ACC_WIDTH,
            ACTIVATION => ACTIVATION
        )
        port map (
            inputs  => inputs,
            weights => weights_reg,
            biases  => biases_reg,
            outputs => layer_outputs
        );

    ----------------------------------------------------------------
    -- Output and status
    ----------------------------------------------------------------
    outputs <= layer_outputs;

    busy <= '1'
        when (state = LOAD_WEIGHTS or state = LOAD_BIASES)
        else '0';

    done <= '1' when state = READY else '0';

end Behavioral;
