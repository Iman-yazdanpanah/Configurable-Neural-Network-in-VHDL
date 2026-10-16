library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.ALL;

entity training_system is
    generic (
        DATA_WIDTH  : positive := 16;
        FRAC_BITS   : natural := 9;
        LAYER_SIZES : positive_array_t := (2, 4, 4, 2);
        ACC_WIDTH   : positive := 40;
        GRAD_WIDTH  : positive := 32
    );
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;
        train_enable : in STD_LOGIC;

        inputs : in STD_LOGIC_VECTOR(
            LAYER_SIZES(LAYER_SIZES'low)*DATA_WIDTH-1 downto 0
        );

        targets : in STD_LOGIC_VECTOR(
            LAYER_SIZES(LAYER_SIZES'high)*DATA_WIDTH-1 downto 0
        );

        learning_rate : in SIGNED(DATA_WIDTH-1 downto 0);

        init_parameter_write_enable : in STD_LOGIC;
        init_parameter_write_address : in integer range
            0 to network_parameter_count(LAYER_SIZES)-1;
        init_parameter_write_data : in SIGNED(DATA_WIDTH-1 downto 0);

        predictions : out STD_LOGIC_VECTOR(
            LAYER_SIZES(LAYER_SIZES'high)*DATA_WIDTH-1 downto 0
        );

        all_activations : out STD_LOGIC_VECTOR(
            network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
        );

        all_deltas : out STD_LOGIC_VECTOR(
            network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
        );

        gradients : out STD_LOGIC_VECTOR(
            network_parameter_count(LAYER_SIZES)*GRAD_WIDTH-1 downto 0
        );

        busy : out STD_LOGIC;
        done : out STD_LOGIC
    );
end entity training_system;


architecture Behavioral of training_system is

    constant TOTAL_WEIGHTS : positive :=
        network_weight_count(LAYER_SIZES);

    constant TOTAL_BIASES : positive :=
        network_bias_count(LAYER_SIZES);

    constant TOTAL_PARAMETERS : positive :=
        network_parameter_count(LAYER_SIZES);

    type state_t is (
        IDLE,
        FORWARD_START,
        FORWARD_WAIT,
        CAPTURE_GRADIENTS,
        START_UPDATE,
        WAIT_UPDATE,
        FINISHED
    );

    signal state : state_t := IDLE;
    signal train_mode_reg : STD_LOGIC := '0';

    signal fwd_start_sig : STD_LOGIC := '0';
    signal network_busy : STD_LOGIC;
    signal network_done : STD_LOGIC;

    signal network_predictions : STD_LOGIC_VECTOR(
        LAYER_SIZES(LAYER_SIZES'high)*DATA_WIDTH-1 downto 0
    );

    signal network_activations : STD_LOGIC_VECTOR(
        network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
    );

    signal network_weights : STD_LOGIC_VECTOR(
        TOTAL_WEIGHTS*DATA_WIDTH-1 downto 0
    );

    signal gradients_comb : STD_LOGIC_VECTOR(
        TOTAL_PARAMETERS*GRAD_WIDTH-1 downto 0
    );

    signal deltas_comb : STD_LOGIC_VECTOR(
        network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
    );

    signal gradients_reg : STD_LOGIC_VECTOR(
        TOTAL_PARAMETERS*GRAD_WIDTH-1 downto 0
    ) := (others => '0');

    signal deltas_reg : STD_LOGIC_VECTOR(
        network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
    ) := (others => '0');

    signal update_start_sig : STD_LOGIC := '0';
    signal update_busy_sig : STD_LOGIC;
    signal update_done_sig : STD_LOGIC;

    signal parameter_read_address_sig : integer range
        0 to TOTAL_PARAMETERS-1 := 0;

    signal parameter_read_data_sig : SIGNED(DATA_WIDTH-1 downto 0);

    signal parameter_write_enable_sig : STD_LOGIC;
    signal parameter_write_address_sig : integer range
        0 to TOTAL_PARAMETERS-1;

    signal parameter_write_data_sig : SIGNED(DATA_WIDTH-1 downto 0);

begin

    ----------------------------------------------------------------
    -- Configurable forward network and parameter memory
    ----------------------------------------------------------------
    NETWORK : entity work.configurable_mlp_memory
        generic map (
            DATA_WIDTH  => DATA_WIDTH,
            FRAC_BITS   => FRAC_BITS,
            LAYER_SIZES => LAYER_SIZES,
            ACC_WIDTH   => ACC_WIDTH
        )
        port map (
            clk   => clk,
            reset => reset,
            start => fwd_start_sig,
            inputs => inputs,

            init_parameter_write_enable =>
                init_parameter_write_enable,
            init_parameter_write_address =>
                init_parameter_write_address,
            init_parameter_write_data =>
                init_parameter_write_data,

            parameter_read_address =>
                parameter_read_address_sig,
            parameter_read_data =>
                parameter_read_data_sig,

            parameter_write_enable =>
                parameter_write_enable_sig,
            parameter_write_address =>
                parameter_write_address_sig,
            parameter_write_data =>
                parameter_write_data_sig,

            predictions => network_predictions,
            all_activations => network_activations,
            all_weights => network_weights,

            busy => network_busy,
            done => network_done
        );


    ----------------------------------------------------------------
    -- Configurable backpropagation
    ----------------------------------------------------------------
    BACKPROPAGATION : entity work.configurable_backpropagation
        generic map (
            DATA_WIDTH  => DATA_WIDTH,
            FRAC_BITS   => FRAC_BITS,
            LAYER_SIZES => LAYER_SIZES,
            ACC_WIDTH   => ACC_WIDTH,
            GRAD_WIDTH  => GRAD_WIDTH
        )
        port map (
            all_activations => network_activations,
            targets         => targets,
            all_weights     => network_weights,
            gradients       => gradients_comb,
            all_deltas      => deltas_comb
        );


    ----------------------------------------------------------------
    -- Update all weights and biases
    ----------------------------------------------------------------
    PARAMETER_UPDATER : entity work.sequential_parameter_updater
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            GRAD_WIDTH => GRAD_WIDTH,
            N_WEIGHTS  => TOTAL_WEIGHTS,
            N_BIASES   => TOTAL_BIASES
        )
        port map (
            clk => clk,
            reset => reset,
            start => update_start_sig,
            learning_rate => learning_rate,
            gradients => gradients_reg,

            memory_read_address => parameter_read_address_sig,
            memory_read_data => parameter_read_data_sig,

            memory_write_enable => parameter_write_enable_sig,
            memory_write_address => parameter_write_address_sig,
            memory_write_data => parameter_write_data_sig,

            busy => update_busy_sig,
            done => update_done_sig
        );


    ----------------------------------------------------------------
    -- Controller
    ----------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                train_mode_reg <= '0';
                fwd_start_sig <= '0';
                update_start_sig <= '0';
                gradients_reg <= (others => '0');
                deltas_reg <= (others => '0');

            else
                fwd_start_sig <= '0';
                update_start_sig <= '0';

                case state is

                    when IDLE =>
                        if start = '1' then
                            train_mode_reg <= train_enable;
                            state <= FORWARD_START;
                        end if;

                    when FORWARD_START =>
                        fwd_start_sig <= '1';
                        state <= FORWARD_WAIT;

                    when FORWARD_WAIT =>
                        if network_done = '1' then
                            if train_mode_reg = '1' then
                                state <= CAPTURE_GRADIENTS;
                            else
                                state <= FINISHED;
                            end if;
                        end if;

                    when CAPTURE_GRADIENTS =>
                        gradients_reg <= gradients_comb;
                        deltas_reg <= deltas_comb;
                        state <= START_UPDATE;

                    when START_UPDATE =>
                        update_start_sig <= '1';
                        state <= WAIT_UPDATE;

                    when WAIT_UPDATE =>
                        if update_done_sig = '1' then
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
        end if;
    end process;


    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------
    predictions <= network_predictions;
    all_activations <= network_activations;
    all_deltas <= deltas_reg;
    gradients <= gradients_reg;

    busy <= '1' when
        state /= IDLE and state /= FINISHED
        else '0';

    done <= '1' when state = FINISHED else '0';

end architecture Behavioral;