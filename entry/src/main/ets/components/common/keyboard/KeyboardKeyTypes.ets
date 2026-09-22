/**
 * 计算按键的稳定视觉语义。
 *
 * 传统表面与沉浸表面都从同一个语义角色派生，避免分别根据按钮内容推断颜色。
 */
export enum KeyboardKeyRole {
  CORE,
  FUNCTION,
  OPERATOR,
  DANGER,
  EMPHASIS,
  SHIFT
}

export interface KeyboardKeySpec {
  content: string | Resource;
  actionId: string;
  role: KeyboardKeyRole;
}
