-- Added for the BSBM relational baseline: secondary indexes on the reverse join columns of the two
-- link tables (BSBM's dump defines only the (product, X) primary keys). Q5 joins productfeatureproduct on
-- productFeature; Q1/Q3/Q4 join producttypeproduct on productType.
CREATE INDEX pfp_feature ON productfeatureproduct (productFeature, product);
CREATE INDEX ptp_type ON producttypeproduct (productType, product);
ANALYZE TABLE productfeatureproduct, producttypeproduct;
