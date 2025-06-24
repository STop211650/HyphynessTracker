export interface BetData {
  sportsbook?: string;
  ticket_number: string;
  type: 'straight' | 'parlay' | 'teaser' | 'round_robin' | 'futures';
  odds: string;
  risk: number;
  to_win: number;
  status: 'pending' | 'won' | 'lost' | 'void' | 'push';
  legs: BetLeg[];
}

export interface BetLeg {
  event: string;
  market: string;
  selection: string;
  odds: string;
}

export interface BetSettlement {
  ticket_number: string;
  status: 'won' | 'lost' | 'void' | 'push';
}

export interface Participant {
  name: string;
  stake: number;
}

export interface AddBetRequest {
  screenshot: string; // base64 encoded
  participants_text: string; // e.g. "Sam: 50, Alex: 30, Jordan: 20"
  who_paid?: string; // Optional: name of person who paid for the bet
}

export interface SettleBetRequest {
  screenshot: string; // base64 encoded
}

export interface RecordPaymentRequest {
  bet_id: string;
  from_user_name: string;
  to_user_name: string;
  amount: number;
  payment_method?: string;
  note?: string;
}