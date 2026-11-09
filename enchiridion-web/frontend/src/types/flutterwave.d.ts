export {};

declare global {
    interface Window {
        FlutterwaveCheckout?: (options: {
            public_key: string;
            tx_ref: string;
            amount: number;
            currency: string;
            customer: { email: string; name: string; phone_number: string };
            customizations: { title: string; description: string };
            meta: Record<string, string>;
            callback: (payment: { transaction_id: number; id: number }) => void;
            onclose: () => void;
        }) => { close: () => void };
    }
}
