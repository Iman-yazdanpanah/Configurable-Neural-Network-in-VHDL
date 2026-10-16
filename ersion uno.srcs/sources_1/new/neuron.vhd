
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.all;

entity neuron is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_INPUTS   : positive := 2;
        ACC_WIDTH  : positive := 40;
        ACTIVATION : activation_t := RELU
    );
    port (
        -- Packed input values. Each input occupies DATA_WIDTH bits.
        inputs  : in  STD_LOGIC_VECTOR(N_INPUTS * DATA_WIDTH - 1 downto 0);

        -- Packed weights, in the same order as the inputs.
        weights : in  STD_LOGIC_VECTOR(N_INPUTS * DATA_WIDTH - 1 downto 0);

        -- Bias in the same fixed-point format as each input.
        bias    : in  SIGNED(DATA_WIDTH - 1 downto 0);

        -- Final neuron output, saturated to DATA_WIDTH bits.
        result  : out SIGNED(DATA_WIDTH - 1 downto 0)
    );
end neuron;

architecture Behavioral of neuron is

    -- Maximum and minimum representable signed output values.
    constant MAX_VALUE : SIGNED(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '0', others => '1');

    constant MIN_VALUE : SIGNED(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '1', others => '0');

begin

    -- Combinational neuron: recalculate whenever an input changes.
    process(inputs, weights, bias)
        variable full_product : SIGNED(2 * DATA_WIDTH - 1 downto 0);
        variable scaled_product : SIGNED(2 * DATA_WIDTH - 1 downto 0);
        variable accumulator : SIGNED(ACC_WIDTH - 1 downto 0);
        variable x_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable w_value : SIGNED(DATA_WIDTH - 1 downto 0);
    begin
        -- Start with zero for each calculation.
        accumulator := (others => '0');

        -- Calculate x0*w0 + x1*w1 + ... .
        for i in 0 to N_INPUTS - 1 loop

            -- Extract one input and its corresponding weight.
            x_value := SIGNED(
                inputs((i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH)
            );

            w_value := SIGNED(
                weights((i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH)
            );

            -- Multiply the fixed-point values.
            full_product := x_value * w_value;

            -- Remove the fractional scaling factor (2**FRAC_BITS).
            scaled_product := SHIFT_RIGHT(full_product, FRAC_BITS);

            -- Add this product to the wider accumulator.
            accumulator := accumulator + RESIZE(scaled_product, ACC_WIDTH);
        end loop;

        -- Add the bias, which already uses the same fixed-point scale.
        accumulator := accumulator + RESIZE(bias, ACC_WIDTH);
        -- Apply the selected activation and saturate the result
        -- to the representable range of the output data type.
        -- Apply the selected activation and saturate the result
        -- to the representable range of the output data type.
        
        if ACTIVATION = RELU then
        
            -- ReLU clamps all negative results to zero.
            if accumulator < to_signed(0, ACC_WIDTH) then
                result <= (others => '0');
        
            elsif accumulator > resize(MAX_VALUE, ACC_WIDTH) then
                result <= MAX_VALUE;
        
            else
                result <= resize(accumulator, DATA_WIDTH);
            end if;
        
        else
            -- LINEAR: preserve negative and positive values,
            -- clamping only when the result exceeds the output range.
            if accumulator > resize(MAX_VALUE, ACC_WIDTH) then
                result <= MAX_VALUE;
        
            elsif accumulator < resize(MIN_VALUE, ACC_WIDTH) then
                result <= MIN_VALUE;
        
            else
                result <= resize(accumulator, DATA_WIDTH);
            end if;
        
        end if;
    end process;

end Behavioral;
