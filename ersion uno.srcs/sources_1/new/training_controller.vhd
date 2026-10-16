
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity training_controller is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        start : in  STD_LOGIC;

        forward_done          : in STD_LOGIC;
        output_gradients_done : in STD_LOGIC;
        hidden_gradients_done : in STD_LOGIC;
        output_update_done    : in STD_LOGIC;
        hidden_update_done    : in STD_LOGIC;

        forward_start          : out STD_LOGIC;
        output_gradients_start : out STD_LOGIC;
        hidden_gradients_start : out STD_LOGIC;
        output_update_start    : out STD_LOGIC;
        hidden_update_start    : out STD_LOGIC;

        busy : out STD_LOGIC;
        done : out STD_LOGIC
    );
end training_controller;

architecture Behavioral of training_controller is

    type state_t is (
        IDLE,
        START_FORWARD,
        WAIT_FORWARD,
        START_OUTPUT_GRADIENTS,
        WAIT_OUTPUT_GRADIENTS,
        START_HIDDEN_GRADIENTS,
        WAIT_HIDDEN_GRADIENTS,
        START_OUTPUT_UPDATE,
        WAIT_OUTPUT_UPDATE,
        START_HIDDEN_UPDATE,
        WAIT_HIDDEN_UPDATE,
        FINISHED
    );

    signal state : state_t := IDLE;

begin

    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;

        elsif rising_edge(clk) then
            case state is

                when IDLE =>
                    if start = '1' then
                        state <= START_FORWARD;
                    end if;

                when START_FORWARD =>
                    state <= WAIT_FORWARD;

                when WAIT_FORWARD =>
                    if forward_done = '1' then
                        state <= START_OUTPUT_GRADIENTS;
                    end if;

                when START_OUTPUT_GRADIENTS =>
                    state <= WAIT_OUTPUT_GRADIENTS;

                when WAIT_OUTPUT_GRADIENTS =>
                    if output_gradients_done = '1' then
                        state <= START_HIDDEN_GRADIENTS;
                    end if;

                when START_HIDDEN_GRADIENTS =>
                    state <= WAIT_HIDDEN_GRADIENTS;

                when WAIT_HIDDEN_GRADIENTS =>
                    if hidden_gradients_done = '1' then
                        state <= START_OUTPUT_UPDATE;
                    end if;

                when START_OUTPUT_UPDATE =>
                    state <= WAIT_OUTPUT_UPDATE;

                when WAIT_OUTPUT_UPDATE =>
                    if output_update_done = '1' then
                        state <= START_HIDDEN_UPDATE;
                    end if;

                when START_HIDDEN_UPDATE =>
                    state <= WAIT_HIDDEN_UPDATE;

                when WAIT_HIDDEN_UPDATE =>
                    if hidden_update_done = '1' then
                        state <= FINISHED;
                    end if;

                when FINISHED =>
                    state <= IDLE;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

    process(state)
    begin
        forward_start          <= '0';
        output_gradients_start <= '0';
        hidden_gradients_start <= '0';
        output_update_start    <= '0';
        hidden_update_start    <= '0';
        busy                   <= '1';
        done                   <= '0';

        case state is

            when IDLE =>
                busy <= '0';

            when START_FORWARD =>
                forward_start <= '1';

            when START_OUTPUT_GRADIENTS =>
                output_gradients_start <= '1';

            when START_HIDDEN_GRADIENTS =>
                hidden_gradients_start <= '1';

            when START_OUTPUT_UPDATE =>
                output_update_start <= '1';

            when START_HIDDEN_UPDATE =>
                hidden_update_start <= '1';

            when FINISHED =>
                busy <= '0';
                done <= '1';

            when others =>
                null;

        end case;
    end process;

end Behavioral;
