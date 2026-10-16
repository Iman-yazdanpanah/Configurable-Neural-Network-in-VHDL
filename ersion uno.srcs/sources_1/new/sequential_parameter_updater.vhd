
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sequential_parameter_updater is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        GRAD_WIDTH : positive := 32;
        N_WEIGHTS  : positive := 2;
        N_BIASES   : positive := 1
    );
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;

        learning_rate : in SIGNED(DATA_WIDTH - 1 downto 0);

        gradients : in STD_LOGIC_VECTOR(
            (N_WEIGHTS + N_BIASES) * GRAD_WIDTH - 1 downto 0
        );

        memory_read_address : out integer range
            0 to N_WEIGHTS + N_BIASES - 1;
        memory_read_data : in SIGNED(DATA_WIDTH - 1 downto 0);

        memory_write_enable : out STD_LOGIC;
        memory_write_address : out integer range
            0 to N_WEIGHTS + N_BIASES - 1;
        memory_write_data : out SIGNED(DATA_WIDTH - 1 downto 0);

        busy : out STD_LOGIC;
        done : out STD_LOGIC
    );
end sequential_parameter_updater;

architecture Behavioral of sequential_parameter_updater is

    constant TOTAL_PARAMETERS : positive :=
        N_WEIGHTS + N_BIASES;

    constant CALC_WIDTH : positive :=
        DATA_WIDTH + GRAD_WIDTH;

    type state_t is (
        IDLE,
        WAIT_READ,
        WRITE_PARAMETER,
        FINISHED
    );

    signal state : state_t := IDLE;

    signal parameter_index : integer range
        0 to TOTAL_PARAMETERS - 1 := 0;

    -- Snapshot all gradients before modifying any parameters.
    signal gradients_latched : STD_LOGIC_VECTOR(
        TOTAL_PARAMETERS*GRAD_WIDTH-1 downto 0
    ) := (others => '0');


    function update_value(
        old_value : SIGNED(DATA_WIDTH - 1 downto 0);
        gradient_value : SIGNED(GRAD_WIDTH - 1 downto 0);
        rate : SIGNED(DATA_WIDTH - 1 downto 0)
    ) return SIGNED is

        variable product_value : SIGNED(CALC_WIDTH - 1 downto 0);
        variable scaled_gradient : SIGNED(CALC_WIDTH - 1 downto 0);
        variable updated_wide : SIGNED(CALC_WIDTH - 1 downto 0);

        variable maximum : SIGNED(DATA_WIDTH - 1 downto 0);
        variable minimum : SIGNED(DATA_WIDTH - 1 downto 0);

        variable result_value : SIGNED(DATA_WIDTH - 1 downto 0);

    begin
        maximum := (others => '1');
        maximum(DATA_WIDTH - 1) := '0';

        minimum := (others => '0');
        minimum(DATA_WIDTH - 1) := '1';

        -- Q9 learning rate * Q9 gradient produces a Q18 product.
        product_value := rate * gradient_value;

        -- Return the update to Q9 scale.
        scaled_gradient := SHIFT_RIGHT(product_value, FRAC_BITS);

        -- Gradient descent.
        updated_wide :=
            RESIZE(old_value, CALC_WIDTH) - scaled_gradient;

        -- Saturate to the DATA_WIDTH signed range.
        if updated_wide > RESIZE(maximum, CALC_WIDTH) then
            result_value := maximum;

        elsif updated_wide < RESIZE(minimum, CALC_WIDTH) then
            result_value := minimum;

        else
            result_value := RESIZE(updated_wide, DATA_WIDTH);
        end if;

        return result_value;
    end function;

begin

    memory_read_address  <= parameter_index;
    memory_write_address <= parameter_index;

    memory_write_enable <= '1'
        when state = WRITE_PARAMETER else '0';

    busy <= '1'
        when state = WAIT_READ or state = WRITE_PARAMETER
        else '0';

    done <= '1' when state = FINISHED else '0';


    ------------------------------------------------------------
    -- Calculate the selected parameter's update using the
    -- latched gradients, not the live gradient input.
    ------------------------------------------------------------
    process(
        parameter_index,
        gradients_latched,
        memory_read_data,
        learning_rate
    )
        variable selected_gradient :
            SIGNED(GRAD_WIDTH - 1 downto 0);

    begin
        selected_gradient := SIGNED(
            gradients_latched(
                (parameter_index + 1)*GRAD_WIDTH - 1
                downto parameter_index*GRAD_WIDTH
            )
        );

        memory_write_data <= update_value(
            memory_read_data,
            selected_gradient,
            learning_rate
        );
    end process;


    ------------------------------------------------------------
    -- Sequential controller
    ------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            parameter_index <= 0;
            gradients_latched <= (others => '0');

        elsif rising_edge(clk) then

            case state is

                when IDLE =>
                    if start = '1' then

                        -- Capture every gradient once, before
                        -- the first parameter write.
                        gradients_latched <= gradients;

                        parameter_index <= 0;
                        state <= WAIT_READ;
                    end if;

                when WAIT_READ =>
                    -- Allow the selected memory value to settle.
                    state <= WRITE_PARAMETER;

                when WRITE_PARAMETER =>
                    -- The parameter memory writes at this edge.
                    if parameter_index = TOTAL_PARAMETERS - 1 then
                        state <= FINISHED;
                    else
                        parameter_index <= parameter_index + 1;
                        state <= WAIT_READ;
                    end if;

                when FINISHED =>
                    if start = '0' then
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

end Behavioral;
