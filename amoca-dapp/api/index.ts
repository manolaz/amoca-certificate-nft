import { ACTIONS, SolanaAgentKit , startMcpServer  } from "solana-agent-kit";
import * as dotenv from "dotenv";

dotenv.config();

const agent = new SolanaAgentKit(
    process.env.WALLET_PRIVATE_KEY!,
    process.env.SOLANA_RPC_URL!,
    {
        OPENAI_API_KEY: process.env.OPENAI_API_KEY || "",
    },
);

// Add your required actions here
const mcp_actions = {
    GET_ASSET: ACTIONS.GET_ASSET_ACTION,
    DEPLOY_TOKEN: ACTIONS.DEPLOY_TOKEN_ACTION,
    // SWAP_TOKEN action is not available in the current version of ACTIONS
    // Consider using alternative token swap implementation
}

startMcpServer(mcp_actions, agent, { name: "solana-agent", version: "0.0.1" });
