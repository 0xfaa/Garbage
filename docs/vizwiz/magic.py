import json

class Stack:
    ELEMENT_SIZE_BYTES = 8
    
    def __init__(self, size=64):
        self.size = size
        self.data = [0] * size
        self.registers = {
            'x0': 0, 'x1': 0, 'x2': 0, 'x3': 0, 
            'x4': 0, 'x5': 0, 'x6': 0, 'x7': 0,
            'x8': 0, 'x9': 0, 'x10': 0,'x11': 0,
            'x12': 0, 'x13': 0, 'x14': 0, 'x15': 0,
            'x16': 0, 'x17': 0, 'x18': 0, 'x19': 0,
            'x20': 0, 'x21': 0, 'x22': 0, 'x23': 0,
            'x24': 0, 'x25': 0, 'x26': 0, 'x27': 0,
            'x28': 0, 'x29': 0, 'x30': 0,
            'sp': (size - 1) * self.ELEMENT_SIZE_BYTES,
            'fp': (size - 1) * self.ELEMENT_SIZE_BYTES,
        }
        self.labels = [[] for _ in range(size)] 
        self.register_labels = {}
        for i in range(31):
            self.register_labels[f'x{i}'] = []
            self.register_labels[f'w{i}'] = []
        self.register_labels['sp'] = []
        self.register_labels['fp'] = []
        self.modified_stack = set()
        self.modified_registers = set()
    
    def to_dict(self):
        return {
            "stack": self.data,
            "registers": self.registers,
            "labels": {i: self.labels[i] for i in range(self.size) if self.labels[i]},
            "register_labels": self.register_labels,
            "modified_stack": list(self.modified_stack),
            "modified_registers": list(self.modified_registers)
        }

    def add_label(self, target: str, label, renders=1):
        if type(target) == str and target.startswith('w'):
            target = 'x' + target[1:]
        if isinstance(target, int):  # Stack label
            self.labels[target].append((label, renders))
        elif target in self.registers:  # Register label
            self.register_labels[target].append((label, renders))
        else:
            raise ValueError(f"Invalid target for label: {target}")

    def decrement_label_renders(self):
        for i in range(self.size):
            self.labels[i] = [(label, renders - 1) for label, renders in self.labels[i] if renders > 1]
        for reg in self.registers:
            self.register_labels[reg] = [(label, renders - 1) for label, renders in self.register_labels[reg] if renders > 1]
    
    def write(self, address, value, size):
        if size > self.ELEMENT_SIZE_BYTES:
            raise ValueError(f"Write size {size} exceeds stack element size {self.ELEMENT_SIZE_BYTES}")
        
        mask = (1 << (size * 8)) - 1
        value &= mask

        self.data[address] = value
        self.modified_stack.add(address)

    def read(self, address, size):
        if size > self.ELEMENT_SIZE_BYTES:
            raise ValueError(f"Read size {size} exceeds stack element size {self.ELEMENT_SIZE_BYTES}")
        
        value = self.data[address]
        
        mask = (1 << (size * 8)) - 1
        return value & mask

    def visualize(self):
        print("Stack:")
        SP_COLOR = '\033[92m'  # Green
        FP_COLOR = '\033[94m'  # Blue
        LABEL_COLOR = '\033[93m'  # Yellow
        MODIFIED_COLOR = '\033[91m'  # Red
        RESET = '\033[0m'      # Reset to default color

        for i in range(self.size - 1, -1, -1):
            value = self.data[i]
            labels = []
            sp_offset = fp_offset = -1
            if i == self.registers['sp'] // self.ELEMENT_SIZE_BYTES:
                labels.append(f"{SP_COLOR}SP{RESET}")
                sp_offset = self.registers['sp'] % self.ELEMENT_SIZE_BYTES
            if i == self.registers['fp'] // self.ELEMENT_SIZE_BYTES:
                labels.append(f"{FP_COLOR}FP{RESET}")
                fp_offset = self.registers['fp'] % self.ELEMENT_SIZE_BYTES
            
            for label, renders in self.labels[i]:
                if renders > 0:
                    labels.append(f"{LABEL_COLOR}{label}{RESET}")
             
            label_str = ", ".join(labels)
            if label_str:
                label_str = "< " + label_str
            
            bytes_str = ""
            for j in range(7, -1, -1):
                byte = (value >> (8*j)) & 0xFF
                if j == sp_offset:
                    bytes_str += f"{SP_COLOR}[{byte:02x}]{RESET}"
                elif j == fp_offset:
                    bytes_str += f"{FP_COLOR}({byte:02x}){RESET}"
                else:
                    byte_str = f"{byte:02x}"
                    
                    ldrb_label = next((label for label, _ in self.labels[i] if label.startswith("ldrb") and f"[{j}]" in label), None)
                    if ldrb_label:
                        byte_str = f"{LABEL_COLOR}{{{byte_str}}}{RESET}"
                        bytes_str += f"{byte_str}"
                    
                    elif i in self.modified_stack:
                        byte_str = f"{MODIFIED_COLOR}{byte_str}{RESET}"
                        bytes_str += f" {byte_str} "
                    else:
                        bytes_str += f" {byte_str} "  
                        
                
            print(f"[{i:2d}]: {bytes_str} | {label_str:>5}")
        
        print("\nRegisters:")
        def format_register(reg, value, labels, is_32bit=False):
            if is_32bit:
                value_str = f"0x{value:08x}"
            else:
                value_str = f"0x{value:016x}"
            if reg in self.modified_registers:
                value_str = f"{MODIFIED_COLOR}{value_str}{RESET}"
            label_str = ", ".join([f"{LABEL_COLOR}{label}{RESET}" for label, renders in labels if renders > 0])
            if label_str:
                label_str = f" < {label_str}"
            return f"{value_str}{label_str}"

        sp_value = self.registers['sp']
        fp_value = self.registers['fp']
        sp_x = format_register('sp', sp_value, self.register_labels.get('sp', []))
        sp_w = format_register('sp', sp_value & 0xFFFFFFFF, self.register_labels.get('sp', []), is_32bit=True)
        fp_x = format_register('fp', fp_value, self.register_labels.get('fp', []))
        fp_w = format_register('fp', fp_value & 0xFFFFFFFF, self.register_labels.get('fp', []), is_32bit=True)

        print(f"{SP_COLOR}sp{RESET}    {sp_x} / {sp_w}")
        print(f"{FP_COLOR}fp{RESET}    {fp_x} / {fp_w}")
        print()

        for i in range(31):  # x0 to x30
            x_reg = f'x{i}'
            w_reg = f'w{i}'
            x_value = self.registers[x_reg]
            w_value = x_value & 0xFFFFFFFF
            x_str = format_register(x_reg, x_value, self.register_labels.get(x_reg, []))
            w_str = format_register(w_reg, w_value, self.register_labels.get(w_reg, []), is_32bit=True)
            print(f"{x_reg:<5} {x_str} / {w_str}")

        print(f"\nStack element size: {self.ELEMENT_SIZE_BYTES} bytes")
        print(f"Note: {SP_COLOR}SP byte is indicated by []{RESET}, {FP_COLOR}FP byte by (){RESET}")
        print(f"      {MODIFIED_COLOR}Red{RESET} indicates modified values")

        self.decrement_label_renders()

    def strb(self, reg: str, base: str, offset=0):
        if reg.startswith('w'):
            x_reg = 'x' + reg[1:]
            byte_value = self.registers[x_reg] & 0xFF
        elif reg.startswith('x'):
            byte_value = self.registers[reg] & 0xFF
        else:
            raise ValueError(f"Invalid register: {reg}")

        if base == 'sp':
            address = self.registers['sp'] + offset
        else:
            address = self.registers[base] + offset

        element_index = address // self.ELEMENT_SIZE_BYTES
        if 0 <= element_index < self.size:
            current_value = self.data[element_index]
            byte_position = address % self.ELEMENT_SIZE_BYTES
            mask = ~(0xFF << (byte_position * 8))
            new_value = (current_value & mask) | (byte_value << (byte_position * 8))
            self.data[element_index] = new_value
        else:
            raise IndexError(f"Memory address out of bounds: {address}")
        
        self.add_label(element_index, f"{reg}[0:8]")
        self.modified_stack.add(element_index)

    def ldrb(self, reg: str, base: str, offset=0):
        if base == 'sp':
            address = self.registers['sp'] + offset
        else:
            address = self.registers[base] + offset

        element_index = address // self.ELEMENT_SIZE_BYTES
        if 0 <= element_index < self.size:
            current_value = self.data[element_index]
            byte_position = address % self.ELEMENT_SIZE_BYTES
            byte_value = (current_value >> (byte_position * 8)) & 0xFF
            
            if reg.startswith('w'):
                x_reg = 'x' + reg[1:]
                self.registers[x_reg] = (self.registers[x_reg] & 0xFFFFFFFF00000000) | byte_value
            elif reg.startswith('x'):
                self.registers[reg] = byte_value
            else:
                raise ValueError(f"Invalid register: {reg}")
            
            # Add label to the register
            self.add_label(reg, f"ldrb [{base}, #{offset}]")
            self.modified_registers.add(reg)
            if reg.startswith('w'):
                self.modified_registers.add(x_reg)
            
            # Add label to the stack element
            stack_label = f"ldrb {reg}[{byte_position}]"
            self.add_label(element_index, stack_label, renders=5)
        else:
            raise IndexError(f"Memory address out of bounds: {address}")

    def add(self, dest, src1, src2, immediate=False):
        if immediate:
            value = self.registers[src1] + src2
        else:
            value = self.registers[src1] + self.registers[src2]
        
        self.registers[dest] = value & 0xFFFFFFFFFFFFFFFF  # Ensure 64-bit result
        
        if dest.startswith('w'):
            # If destination is a 32-bit register, mask the result to 32 bits
            self.registers[dest] = value & 0xFFFFFFFF
        self.add_label(dest, f"add {dest}")
        self.modified_registers.add(dest)

    def sub(self, dest, src1, src2, immediate=False):
        if immediate:
            value = self.registers[src1] - src2
        else:
            value = self.registers[src1] - self.registers[src2]
        
        self.registers[dest] = value & 0xFFFFFFFFFFFFFFFF  # Ensure 64-bit result
        
        if dest.startswith('w'):
            # If destination is a 32-bit register, mask the result to 32 bits
            self.registers[dest] = value & 0xFFFFFFFF
        self.add_label(dest, f"sub {dest}")
        self.modified_registers.add(dest)

    def stp(self, reg1, reg2, base, offset, writeback=False):
        if base == 'sp':
            address = self.registers['sp'] + offset
        else:
            address = self.registers[base] + offset

        if address < 0 or address >= self.size * self.ELEMENT_SIZE_BYTES:
            raise IndexError(f"STP operation out of stack bounds: {address}")

        # Store the first register
        value1 = self.registers[reg1]
        element_index1 = address // self.ELEMENT_SIZE_BYTES
        self.data[element_index1] = value1
        self.add_label(element_index1, f"stp {reg1}", renders=5)

        # Store the second register
        value2 = self.registers[reg2]
        element_index2 = (address + 8) // self.ELEMENT_SIZE_BYTES
        self.data[element_index2] = value2
        self.add_label(element_index2, f"stp {reg2}", renders=5)

        if writeback:
            if base == 'sp':
                self.registers['sp'] = address
            self.registers[base] = address

        self.modified_stack.add(element_index1)
        self.modified_stack.add(element_index2)
        if writeback:
            self.modified_registers.add(base)

    def mov(self, dest, src):
        if src.startswith('#'):
            # Immediate value
            value = int(src[1:])  # Remove '#' and convert to int
        elif src in self.registers or (src.startswith('w') and f'x{src[1:]}' in self.registers):
            # Register to register move
            if src.startswith('w'):
                value = self.registers[f'x{src[1:]}'] & 0xFFFFFFFF
            else:
                value = self.registers[src]
        else:
            raise ValueError(f"Invalid source for mov: {src}")
        
        if dest.startswith('w'):
            # If destination is a 32-bit register, mask the result to 32 bits
            value &= 0xFFFFFFFF
            x_dest = f'x{dest[1:]}'
            self.registers[x_dest] = (self.registers[x_dest] & 0xFFFFFFFF00000000) | value
        else:
            self.registers[dest] = value
        
        # add stack label if the source is sp or fp
        if src == 'sp' or src == 'fp':
            self.add_label(self.registers[src] // self.ELEMENT_SIZE_BYTES, f'{dest}', renders=1000)
        
        self.add_label(dest, f"mov {src}")
        self.modified_registers.add(dest)
        if dest.startswith('w'):
            self.modified_registers.add(f'x{dest[1:]}')
 
def print_stack(instruction = ''):
    print('-'*48)
    print(f"Executed: {instruction}")
    stack.visualize()
    print()

def parse_and_execute(stack: Stack, instruction: str):
    parts = instruction.split()
    if len(parts) == 0:
        print('instruction is empty')
        return

    if parts[0] == 'strb':
        reg = parts[1].strip(',')
        target = parts[2]
        if len(parts) == 4:
            target += parts[3]
        mem_parts = target.strip('[]').split(',')
        base = mem_parts[0]
        if len(mem_parts) > 1:
            offset = int(mem_parts[1].replace('#', ''))  # Remove the '#' and convert to int
        else:
            offset = 0
        stack.strb(reg, base, offset)
    elif parts[0] == 'ldrb':
        reg = parts[1].strip(',')
        target = parts[2]
        if len(parts) == 4:
            target += parts[3]
        mem_parts = target.strip('[]').split(',')
        base = mem_parts[0]
        if len(mem_parts) > 1:
            offset = int(mem_parts[1].replace('#', ''))  # Remove the '#' and convert to int
        else:
            offset = 0
        stack.ldrb(reg, base, offset)
    elif parts[0] == 'add':
        dest = parts[1].strip(',')
        src1 = parts[2].strip(',')
        if parts[3].startswith('#'):
            # Immediate value
            src2 = int(parts[3].replace('#', ''))  # Remove '#' and convert to int
            stack.add(dest, src1, src2, immediate=True)
        else:
            # Register
            src2 = parts[3].strip(',')
            stack.add(dest, src1, src2)
    elif parts[0] == 'sub':
        dest = parts[1].strip(',')
        src1 = parts[2].strip(',')
        if parts[3].startswith('#'):
            # Immediate value
            src2 = int(parts[3].replace('#', ''))  # Remove '#' and convert to int
            stack.sub(dest, src1, src2, immediate=True)
        else:
            # Register
            src2 = parts[3].strip(',')
            stack.sub(dest, src1, src2)
    elif parts[0] == 'stp':
        reg1, reg2 = parts[1].replace(',', ''), parts[2].replace(',', '')
        mem_part = parts[3] + parts[4]
        if mem_part.endswith('!'):
            writeback = True
            mem_part = mem_part[:-1]
        else:
            writeback = False
        base, offset = mem_part.strip('[]').split(',')
        offset = int(offset.replace('#', ''))
        stack.stp(reg1, reg2, base, offset, writeback)
        
    elif parts[0] == 'mov':
        dest = parts[1].strip(',')
        src = parts[2].strip()
        stack.mov(dest, src)
        
    print_stack(instruction)
    return stack.to_dict()
    
stack = Stack(16)  # Smaller stack for demonstration

# Example usage with the provided assembly code
assembly_code = """
stp x29, x30, [sp, #-16]!
mov x29, sp
sub sp, sp, #48
mov w0, #63
strb w0, [x29, #-32]
add x0, x29, #-33
mov x1, x0
mov w0, #1
mov x2, x0
mov x3, #1
cmp x2, x3
csel x2, x2, x3, ls
mov x0, #1     ; stdout file descriptor
mov x16, #4    ; write syscall number
svc 0
add sp, sp, #32
ldp x29, x30, [sp], #16
"""

stack.registers['x29'] = 0x1111111111111111
stack.registers['x30'] = 0x2222222222222222

print_stack('START')

json_states = []
for instruction in assembly_code.strip().split('\n'):
    state = parse_and_execute(stack, instruction)
    json_states.append(state)

with open(f"stack_states.json", "w") as f:
    # f.write(json.dumps())
    json.dump(json_states, f, indent=2)