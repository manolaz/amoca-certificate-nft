module amoca_certificate_nft::certificate {
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::package;
    use sui::display;

    // One-Time-Witness for the module
    struct CERTIFICATE has drop {}

    // The Certificate NFT struct
    struct Certificate has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
        issuer: String,
        recipient: String,
        issue_date: String,
        certificate_type: String,
        metadata: String,
        verification_hash: String,
    }

    // Certificate Collection for managing multiple certificates
    struct CertificateCollection has key {
        id: UID,
        name: String,
        description: String,
        owner: address,
    }

    // Events
    struct CertificateCreated has copy, drop {
        certificate_id: ID,
        name: String,
        recipient: String,
        issuer: String,
    }

    struct CertificateTransferred has copy, drop {
        certificate_id: ID,
        from: address,
        to: address,
    }

    // === Functions ===

    // Initialize the module
    fun init(witness: CERTIFICATE, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        
        // Create a display for the Certificate NFT
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"issuer"),
            string::utf8(b"recipient"),
            string::utf8(b"issue_date"),
            string::utf8(b"certificate_type"),
        ];

        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"{image_url}"),
            string::utf8(b"{issuer}"),
            string::utf8(b"{recipient}"),
            string::utf8(b"{issue_date}"),
            string::utf8(b"{certificate_type}"),
        ];

        let display = display::new_with_fields<Certificate>(
            &publisher, keys, values, ctx
        );

        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }

    // Create a new certificate collection
    public entry fun create_collection(
        name: vector<u8>,
        description: vector<u8>,
        ctx: &mut TxContext
    ) {
        let collection = CertificateCollection {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            owner: tx_context::sender(ctx),
        };

        transfer::transfer(collection, tx_context::sender(ctx));
    }

    // Mint a new certificate NFT
    public entry fun mint_certificate(
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        issuer: vector<u8>,
        recipient: vector<u8>,
        issue_date: vector<u8>,
        certificate_type: vector<u8>,
        metadata: vector<u8>,
        verification_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let certificate = Certificate {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            image_url: url::new_unsafe_from_bytes(image_url),
            issuer: string::utf8(issuer),
            recipient: string::utf8(recipient),
            issue_date: string::utf8(issue_date),
            certificate_type: string::utf8(certificate_type),
            metadata: string::utf8(metadata),
            verification_hash: string::utf8(verification_hash),
        };

        // Emit event
        event::emit(CertificateCreated {
            certificate_id: object::id(&certificate),
            name: certificate.name,
            recipient: certificate.recipient,
            issuer: certificate.issuer,
        });

        transfer::transfer(certificate, tx_context::sender(ctx));
    }

    // Transfer a certificate to a new owner
    public entry fun transfer_certificate(certificate: Certificate, recipient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        
        // Emit transfer event
        event::emit(CertificateTransferred {
            certificate_id: object::id(&certificate),
            from: sender,
            to: recipient,
        });

        transfer::transfer(certificate, recipient);
    }

    // Get certificate details
    public fun get_certificate_details(certificate: &Certificate): (
        String, String, Url, String, String, String, String, String, String
    ) {
        (
            certificate.name,
            certificate.description,
            certificate.image_url,
            certificate.issuer,
            certificate.recipient,
            certificate.issue_date,
            certificate.certificate_type,
            certificate.metadata,
            certificate.verification_hash
        )
    }

    // Verify certificate authenticity
    public fun verify_certificate(certificate: &Certificate, hash: vector<u8>): bool {
        string::utf8(hash) == certificate.verification_hash
    }
}