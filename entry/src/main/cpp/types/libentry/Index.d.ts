// entry/src/main/cpp/types/libentry/index.d.ts
export interface CalcConfig {
  isRad: boolean;
  precision: number;
  mode: number;
  xMin?: number;
  xMax?: number;
  pointsCount?: number;
}

export const calculate: (jsonStr: string, config: CalcConfig) => string;