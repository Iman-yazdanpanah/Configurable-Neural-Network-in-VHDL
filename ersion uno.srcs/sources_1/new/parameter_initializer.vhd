
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_initializer is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_WEIGHTS  : positive := 6;
        N_BIASES   : positive := 3
    );
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        start : in  STD_LOGIC;
        seed  : in  STD_LOGIC_VECTOR(15 downto 0);

        busy : out STD_LOGIC;
        done : out STD_LOGIC;

        -- Weight memory write interface
        weight_write_enable : out STD_LOGIC;
        weight_write_addr   : out integer range 0 to N_WEIGHTS - 1;
        weight_write_data   : out SIGNED(DATA_WIDTH - 1 downto 0);

        -- Bias memory write interface
        bias_write_enable : out STD_LOGIC;
        bias_write_addr   : out integer range 0 to N_BIASES - 1;
        bias_write_data   : out SIGNED(DATA_WIDTH - 1 downto 0)
    );
end parameter_initializer;

architecture Behavioral of parameter_initializer is

    type state_t is (
        IDLE,
        LOAD_SEED,
        INIT_WEIGHTS,
        INIT_BIASES,
        FINISHED
    );

    signal state : state_t := IDLE;

    signal weight_count : integer range 0 to N_WEIGHTS - 1 := 0;
    signal bias_count   : integer range 0 to N_BIASES - 1 := 0;

    signal lfsr_seed_load : STD_LOGIC := '0';
    signal lfsr_enable    : STD_LOGIC := '0';

    signal random_value : SIGNED(DATA_WIDTH - 1 downto 0);

begin

    ----------------------------------------------------------------
    -- Random number generator
    ----------------------------------------------------------------
    RANDOM_GENERATOR : entity work.lfsr_random
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS
        )
        port map (
            clk          => clk,
            reset        => reset,
            seed_load    => lfsr_seed_load,
            seed         => seed,
            enable       => lfsr_enable,
            random_value => random_value
        );

    ----------------------------------------------------------------
    -- Sequential controller
    ----------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state        <= IDLE;
            weight_count <= 0;
            bias_count   <= 0;

        elsif rising_edge(clk) then

            case state is

                when IDLE =>
                    weight_count <= 0;
                    bias_count   <= 0;

                    if start = '1' then
                        state <= LOAD_SEED;
                    end if;

                when LOAD_SEED =>
                    -- The LFSR loads the seed on this clock edge.
                    state <= INIT_WEIGHTS;

                when INIT_WEIGHTS =>
                    if weight_count = N_WEIGHTS - 1 then
                        bias_count <= 0;
                        state      <= INIT_BIASES;
                    else
                        weight_count <= weight_count + 1;
                    end if;

                when INIT_BIASES =>
                    if bias_count = N_BIASES - 1 then
                        state <= FINISHED;
                    else
                        bias_count <= bias_count + 1;
                    end if;

                when FINISHED =>
                    -- Wait for start to be released.
                    if start = '0' then
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

    ----------------------------------------------------------------
    -- LFSR controls
    --
    -- Controls are derived directly from the current state.
    ----------------------------------------------------------------
    lfsr_seed_load <= '1' when state = LOAD_SEED else '0';

    lfsr_enable <= '1'
        when (state = INIT_WEIGHTS or state = INIT_BIASES)
        else '0';

    ----------------------------------------------------------------
    -- Weight memory write interface
    ----------------------------------------------------------------
    weight_write_enable <= '1' when state = INIT_WEIGHTS else '0';

    weight_write_addr <= weight_count;

    weight_write_data <= random_value;

    ----------------------------------------------------------------
    -- Bias memory write interface
    ----------------------------------------------------------------
    bias_write_enable <= '1' when state = INIT_BIASES else '0';

    bias_write_addr <= bias_count;

    bias_write_data <= random_value;

    ----------------------------------------------------------------
    -- Status outputs
    ----------------------------------------------------------------
    busy <= '1'
        when (state = LOAD_SEED or
              state = INIT_WEIGHTS or
              state = INIT_BIASES)
        else '0';

    done <= '1' when state = FINISHED else '0';

end Behavioral;
