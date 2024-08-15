import { State } from "./state"

export interface Registers {
    'x0':bigint, 'x1':bigint, 'x2':bigint, 'x3':bigint, 
    'x4':bigint, 'x5':bigint, 'x6':bigint, 'x7':bigint,
    'x8':bigint, 'x9':bigint, 'x10':bigint,'x11':bigint,
    'x12':bigint, 'x13':bigint, 'x14':bigint, 'x15':bigint,
    'x16':bigint, 'x17':bigint, 'x18':bigint, 'x19':bigint,
    'x20':bigint, 'x21':bigint, 'x22':bigint, 'x23':bigint,
    'x24':bigint, 'x25':bigint, 'x26':bigint, 'x27':bigint,
    'x28':bigint, 'x29':bigint, 'x30':bigint,
    'sp': bigint,
    'fp': bigint,
}

export class Stack {

    public readonly ELEMENT_SIZE_BYTES = 8

    public size: number
    public data: bigint[]
    public registers: Registers
    public labels: [string, number][][]
    public register_labels: { [key: string]: [string, number][] }
    public modified_stack: Set<bigint>
    public modified_registers: Set<string>

    constructor (size: number = 64) {
        this.size = size
        this.data = new Array(size).fill(0n)
        this.registers = {
            'x0': 0n, 'x1': 0n, 'x2': 0n, 'x3': 0n, 
            'x4': 0n, 'x5': 0n, 'x6': 0n, 'x7': 0n,
            'x8': 0n, 'x9': 0n, 'x10': 0n,'x11': 0n,
            'x12': 0n, 'x13': 0n, 'x14': 0n, 'x15': 0n,
            'x16': 0n, 'x17': 0n, 'x18': 0n, 'x19': 0n,
            'x20': 0n, 'x21': 0n, 'x22': 0n, 'x23': 0n,
            'x24': 0n, 'x25': 0n, 'x26': 0n, 'x27': 0n,
            'x28': 0n, 'x29': 0n, 'x30': 0n,
            'sp': BigInt((size - 1) * this.ELEMENT_SIZE_BYTES),
            'fp': BigInt((size - 1) * this.ELEMENT_SIZE_BYTES),
        }
        this.labels = new Array(size).fill(null).map(() => []);
        this.register_labels = {}
        for (let i = 0; i < 31; i++) {
            this.register_labels[`x${i}`] = []
            this.register_labels[`w${i}`] = []
        }
        this.register_labels['sp'] = []
        this.register_labels['fp'] = []
        this.modified_stack = new Set()
        this.modified_registers = new Set()
    }

    public snapshot(instruction: string = ''): State {
        const replacer = (_key: string, value: unknown) => {
            if (typeof value === 'bigint') {
                return value.toString();
            }
            return value;
        };
    
        return JSON.parse(JSON.stringify({
            instruction,
            stack: this.data.map(v => v.toString()),
            registers: Object.fromEntries(
                Object.entries(this.registers).map(([k, v]) => [k, v.toString()])
            ),
            labels: Object.fromEntries(
                this.labels.map((labelArray, index) => 
                    [index, labelArray.length > 0 ? labelArray : undefined]
                ).filter(([, value]) => value !== undefined)
            ),
            register_labels: this.register_labels,
            modified_stack: Array.from(this.modified_stack).map(v => v.toString()),
            modified_registers: Array.from(this.modified_registers)
        }, replacer));
    }

    public addLabel(target: string | number, label: string, renders: number = 1) {
        if (typeof target === 'string' && target.startsWith('w')) target = 'x' + target.slice(1)
        // stack label
        if (typeof target === 'number') {
            if (target >= 0 && target < this.size) {
                // Check if the label already exists
                const existingLabelIndex = this.labels[target].findIndex(([l]) => l === label);
                if (existingLabelIndex !== -1) {
                    // Update existing label
                    this.labels[target][existingLabelIndex] = [label, renders];
                } else {
                    // Add new label
                    this.labels[target].push([label, renders]);
                }
            }
        }
        // register label
        else if (Object.keys(this.registers).includes(target)) {
            const existingLabelIndex = this.register_labels[target].findIndex(([l]) => l === label);
            if (existingLabelIndex !== -1) {
                // Update existing label
                this.register_labels[target][existingLabelIndex] = [label, renders];
            } else {
                // Add new label
                this.register_labels[target].push([label, renders]);
            }
        }
        else throw new Error(`Invalid target for label: ${target}`);
    }

    public decrement_label_renders(): void {
        for (let i = 0; i < this.size; i++) {
            this.labels[i] = this.labels[i].filter(([, renders]) => renders > 1)
                .map(([label, renders]) => [label, renders - 1]);
        }

        // TODO: implemen this shit
        // for (const key of Object.keys(this.register_labels)) {
        //     for (const jey of Object.keys(this.register_labels[key])) {
        //         if (this.register_labels[key][jey][1])
        //     }
        // }
    }

    public write(address: number, value: bigint, size: number): void {
        if (size > this.ELEMENT_SIZE_BYTES) {
            throw new Error(`Write size ${size} exceeds stack element size ${this.ELEMENT_SIZE_BYTES}`);
        }
        
        const mask = (1n << BigInt(size * 8)) - 1n;
        value &= mask;

        this.data[address] = value;
        this.modified_stack.add(BigInt(address));
    }

    public read(address: number, size: number): bigint {
        if (size > this.ELEMENT_SIZE_BYTES) {
            throw new Error(`Read size ${size} exceeds stack element size ${this.ELEMENT_SIZE_BYTES}`);
        }
        
        const value = this.data[address];
        
        const mask = (1n << BigInt(size * 8)) - 1n;
        return value & mask;
    }

    public sub(dest: keyof Registers, src1: keyof Registers, src2: keyof Registers | bigint, immediate: boolean = false) {
        let value;
        
        if (immediate && typeof src2 === 'bigint') {
            value = this.registers[src1] - src2
        }
        else if (typeof src2 !== 'bigint') {
            value = this.registers[src1] - this.registers[src2]
        } else {
            throw new Error(`Some kind of weird src2 for sub operation: ${src2}`)
        }

        this.registers[dest] = value & BigInt("0xFFFFFFFFFFFFFFFF")

        if (dest.startsWith('w')) {
            this.registers[dest] = value & BigInt("0xFFFFFFFF")
        }

        this.addLabel(dest, `sub ${dest}`)
        this.modified_registers.add(dest)
    }

    public add(dest: keyof Registers, src1: keyof Registers, src2: keyof Registers | bigint, immediate: boolean = false): void {
        let value: bigint;
        if (immediate && typeof src2 === 'bigint') {
            value = this.registers[src1] + src2;
        } else if (typeof src2 !== 'bigint') {
            value = this.registers[src1] + this.registers[src2];
        } else {
            throw new Error(`Invalid src2 for add operation: ${src2}`);
        }

        this.registers[dest] = value & 0xFFFFFFFFFFFFFFFFn;

        if (dest.startsWith('w')) {
            this.registers[dest] = value & 0xFFFFFFFFn;
        }

        this.addLabel(dest, `add ${dest}`);
        this.modified_registers.add(dest);
    }

    public strb(reg: string, base: keyof Registers, offset: number = 0): void {
        let byte_value: bigint;
        if (reg.startsWith('w')) {
            const x_reg = 'x' + reg.slice(1);
            byte_value = this.registers[x_reg as keyof Registers] & 0xFFn;
        } else if (reg.startsWith('x')) {
            byte_value = this.registers[reg as keyof Registers] & 0xFFn;
        } else {
            throw new Error(`Invalid register: ${reg}`);
        }

        const address = base === 'sp' ? this.registers['sp'] + BigInt(offset) : this.registers[base] + BigInt(offset);

        const element_index = Number(address / BigInt(this.ELEMENT_SIZE_BYTES));
        if (0 <= element_index && element_index < this.size) {
            const current_value = this.data[element_index];
            const byte_position = Number(address % BigInt(this.ELEMENT_SIZE_BYTES));
            const mask = ~(0xFFn << BigInt(byte_position * 8));
            const new_value = (current_value & mask) | (byte_value << BigInt(byte_position * 8));
            this.data[element_index] = new_value;
        } else {
            throw new Error(`Memory address out of bounds: ${address}`);
        }

        this.addLabel(element_index, `${reg}[0:8]`);
        this.modified_stack.add(BigInt(element_index));
    }


    public ldrb(reg: string, base: keyof Registers, offset: number = 0): void {
        const address = base === 'sp' ? this.registers['sp'] + BigInt(offset) : this.registers[base] + BigInt(offset);

        const element_index = Number(address / BigInt(this.ELEMENT_SIZE_BYTES));
        if (0 <= element_index && element_index < this.size) {
            const current_value = this.data[element_index];
            const byte_position = Number(address % BigInt(this.ELEMENT_SIZE_BYTES));
            const byte_value = (current_value >> BigInt(byte_position * 8)) & 0xFFn;

            if (reg.startsWith('w')) {
                const x_reg = 'x' + reg.slice(1);
                this.registers[x_reg as keyof Registers] = (this.registers[x_reg as keyof Registers] & 0xFFFFFFFF00000000n) | byte_value;
            } else if (reg.startsWith('x')) {
                this.registers[reg as keyof Registers] = byte_value;
            } else {
                throw new Error(`Invalid register: ${reg}`);
            }

            this.addLabel(reg, `ldrb [${base}, #${offset}]`);
            this.modified_registers.add(reg);
            if (reg.startsWith('w')) {
                this.modified_registers.add('x' + reg.slice(1));
            }

            const stack_label = `ldrb ${reg}[${byte_position}]`;
            this.addLabel(element_index, stack_label, 1);
        } else {
            throw new Error(`Memory address out of bounds: ${address}`);
        }
    }

    public stp(reg1: keyof Registers, reg2: keyof Registers, base: keyof Registers, offset: number, writeback: boolean = false): void {
        const address = base === 'sp' ? this.registers['sp'] + BigInt(offset) : this.registers[base] + BigInt(offset);

        if (address < 0n || address >= BigInt(this.size * this.ELEMENT_SIZE_BYTES)) {
            throw new Error(`STP operation out of stack bounds: ${address}`);
        }

        // Store the first register
        const value1 = this.registers[reg1];
        const element_index1 = Number(address / BigInt(this.ELEMENT_SIZE_BYTES));
        this.data[element_index1] = value1;
        this.addLabel(element_index1, `stp ${reg1}`, 1);

        // Store the second register
        const value2 = this.registers[reg2];
        const element_index2 = Number((address + 8n) / BigInt(this.ELEMENT_SIZE_BYTES));
        this.data[element_index2] = value2;
        this.addLabel(element_index2, `stp ${reg2}`, 1);

        if (writeback) {
            if (base === 'sp') {
                this.registers['sp'] = address;
            }
            this.registers[base] = address;
        }

        this.modified_stack.add(BigInt(element_index1));
        this.modified_stack.add(BigInt(element_index2));
        if (writeback) {
            this.modified_registers.add(base);
        }
    }

    public mov(dest: keyof Registers, src: string | keyof Registers): void {
        let value: bigint;
        if (src.startsWith('#')) {
            // Immediate value
            value = BigInt(src.slice(1)); // Remove '#' and convert to BigInt
        } else if (src in this.registers || (src.startsWith('w') && `x${src.slice(1)}` in this.registers)) {
            // Register to register move
            if (src.startsWith('w')) {
                value = this.registers[`x${src.slice(1)}` as keyof Registers] & 0xFFFFFFFFn;
            } else {
                value = this.registers[src as keyof Registers];
            }
        } else {
            throw new Error(`Invalid source for mov: ${src}`);
        }
    
        if (dest.startsWith('w')) {
            // If destination is a 32-bit register, mask the result to 32 bits
            value &= 0xFFFFFFFFn;
            const x_dest = `x${dest.slice(1)}` as keyof Registers;
            this.registers[x_dest] = (this.registers[x_dest] & 0xFFFFFFFF00000000n) | value;
        } else {
            this.registers[dest] = value;
        }
    
        // add stack label if the source is sp or fp
        if (src === 'sp' || src === 'fp') {
            const labelIndex = Number(this.registers[src as keyof Registers] / BigInt(this.ELEMENT_SIZE_BYTES));
            if (labelIndex >= 0 && labelIndex < this.size) {
                this.labels[labelIndex] = [[`${dest}`, 1]];  // Replace any existing labels
            }
        } 
    
        this.addLabel(dest, `mov ${src}`);
    
        this.modified_registers.add(dest);
        if (dest.startsWith('w')) {
            this.modified_registers.add(`x${dest.slice(1)}`);
        }
    }
}