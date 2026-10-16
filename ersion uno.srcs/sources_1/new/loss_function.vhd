
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity loss_function is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_OUTPUTS  : positive := 2;
        ACC_WIDTH  : positive := 40
    );
    port (
        predictions : in STD_LOGIC_VECTOR(
            N_OUTPUTS * DATA_WIDTH - 1 downto 0
        );

        targets : in STD_LOGIC_VECTOR(
            N_OUTPUTS * DATA_WIDTH - 1 downto 0
        );

        loss : out SIGNED(ACC_WIDTH - 1 downto 0)
    );
end loss_function;

architecture Behavioral of loss_function is
    -- One extra bit allows subtraction of two signed
    -- DATA_WIDTH-bit values without immediate overflow.
    constant ERR_WIDTH : positive := DATA_WIDTH + 1;
begin

    process(predictions, targets)
        variable predicted_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable target_value    : SIGNED(DATA_WIDTH - 1 downto 0);

        variable error_value : SIGNED(ERR_WIDTH - 1 downto 0);

        -- Squaring doubles the operand width.
        variable squared_error : SIGNED(2 * ERR_WIDTH - 1 downto 0);

        variable scaled_error : SIGNED(2 * ERR_WIDTH - 1 downto 0);

        variable accumulator : SIGNED(ACC_WIDTH - 1 downto 0);
    begin
        accumulator := (others => '0');

        for i in 0 to N_OUTPUTS - 1 loop

            -- Extract one prediction and its corresponding target.
            predicted_value := SIGNED(
                predictions((i + 1) * DATA_WIDTH - 1
                            downto i * DATA_WIDTH)
            );

            target_value := SIGNED(
                targets((i + 1) * DATA_WIDTH - 1
                        downto i * DATA_WIDTH)
            );

            -- Calculate prediction error.
            error_value :=
                RESIZE(predicted_value, ERR_WIDTH) -
                RESIZE(target_value, ERR_WIDTH);

            -- Square the error.
            squared_error := error_value * error_value;

            -- Restore the fixed-point scale.
            -- Both operands represent values scaled by 2^FRAC_BITS.
            scaled_error := SHIFT_RIGHT(squared_error, FRAC_BITS);

            -- Add this squared error to the total loss.
            accumulator := accumulator +
                           RESIZE(scaled_error, ACC_WIDTH);

        end loop;

        -- SSE is returned as a fixed-point value.
        loss <= accumulator;
    end process;

end Behavioral;
