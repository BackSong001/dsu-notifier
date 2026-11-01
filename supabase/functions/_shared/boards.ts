export const BOARDS = [
  { code: "MN2000194", name: "학사", url: "https://www.dongseo.ac.kr/kr/?pCode=MN2000194" },
  { code: "MN2000191", name: "공지/행사", url: "https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000191" },
  { code: "job_plus", name: "취업", url: "https://www.dongseo.ac.kr/kr/index.php?pCode=job_plus" },
  { code: "MN2000197", name: "모집", url: "https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000197" },
  { code: "MN2000195", name: "장학", url: "https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000195" },
  { code: "MN2000196", name: "입찰", url: "https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000196" },
] as const;

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};
