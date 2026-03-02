"""Initial ledger schema

Revision ID: 001
Create Date: 2026-01-30
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Stores table
    op.create_table(
        'stores',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('name_ar', sa.String(255)),
        sa.Column('phone', sa.String(20), unique=True, nullable=False),
        sa.Column('address', sa.Text),
        sa.Column('logo_url', sa.Text),
        sa.Column('join_code', sa.String(6), unique=True, nullable=False),
        sa.Column('password_hash', sa.String(255)),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
    )
    op.create_index('ix_stores_phone', 'stores', ['phone'])
    op.create_index('ix_stores_join_code', 'stores', ['join_code'])
    
    # Customers table
    op.create_table(
        'customers',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('name_ar', sa.String(255)),
        sa.Column('phone', sa.String(20), unique=True, nullable=False),
        sa.Column('password_hash', sa.String(255)),
        sa.Column('push_token', sa.Text),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
    )
    op.create_index('ix_customers_phone', 'customers', ['phone'])
    
    # Ledger entries (store-customer relationship)
    op.create_table(
        'ledger_entries',
        sa.Column('store_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('stores.id'), primary_key=True),
        sa.Column('customer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customers.id'), primary_key=True),
        sa.Column('total_owed', sa.Numeric(10, 2), server_default='0'),
        sa.Column('last_activity_at', sa.DateTime, server_default=sa.func.now()),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
    )
    
    # Products table
    op.create_table(
        'products',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('store_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('stores.id')),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('name_ar', sa.String(255)),
        sa.Column('description', sa.Text),
        sa.Column('image_url', sa.Text),
        sa.Column('category', sa.String(50)),
        sa.Column('default_price', sa.Numeric(10, 2)),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
    )
    op.create_index('ix_products_store_id', 'products', ['store_id'])
    
    # Bills table
    op.create_table(
        'bills',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('store_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('stores.id'), nullable=False),
        sa.Column('customer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customers.id'), nullable=False),
        sa.Column('total_amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('status', sa.Enum('pending', 'paid', 'disputed', name='billstatus'), server_default='pending'),
        sa.Column('receipt_image_url', sa.Text),
        sa.Column('notes', sa.Text),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
        sa.Column('paid_at', sa.DateTime),
    )
    op.create_index('ix_bills_store_customer', 'bills', ['store_id', 'customer_id'])
    op.create_index('ix_bills_status', 'bills', ['status'])
    
    # Bill items table
    op.create_table(
        'bill_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('bill_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('bills.id', ondelete='CASCADE'), nullable=False),
        sa.Column('product_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('products.id')),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('name_ar', sa.String(255)),
        sa.Column('image_url', sa.Text),
        sa.Column('quantity', sa.Numeric(10, 3), server_default='1'),
        sa.Column('unit_price', sa.Numeric(10, 2), nullable=False),
        sa.Column('total_price', sa.Numeric(10, 2), nullable=False),
    )
    op.create_index('ix_bill_items_bill_id', 'bill_items', ['bill_id'])


def downgrade() -> None:
    op.drop_table('bill_items')
    op.drop_table('bills')
    op.drop_table('products')
    op.drop_table('ledger_entries')
    op.drop_table('customers')
    op.drop_table('stores')
    op.execute('DROP TYPE IF EXISTS billstatus')
