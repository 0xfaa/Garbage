export interface State {
    instruction: string;
    labels: {
      [key: number]: [string, number][];
    };
    modified_registers: string[];
    modified_stack: bigint[];
    register_labels: {
      [key: string]: [string, number][];
    };
    registers: {
      [key: string]: string;
    };
    stack: string[];
  }