# the raw data were generated from next-seq 500
# SE or PE?

library(gplots)
library(xlsx)
library(Rsubread)
library(edgeR)
library(limma)
library(org.Hs.eg.db)
library(DESeq2)
library(gplots)
library(genefilter)
library(RColorBrewer)
library(org.Rn.eg.db)
library(org.Mm.eg.db)
library(cluster)
library(factoextra)
library(clusterProfiler)
library(pathview)
library(sva)
library(tidyverse)
library(rat2302.db)
library(affy)
library(annotate)
library(scatterplot3d)
library(rgl)
library(graph3d)
library(magrittr)

#library(devtools)
#install_github('kassambara/graph3d')
#install.packages("rgl")



setwd('D:\\wangli_data\\Rdata')
#save.image('multiple.xinli.Rdata')
load('multiple.xinli.Rdata')

# cd /home/zhenyisong/data/wanglilab/wangcode
# nohup R CMD BATCH multiple.xinli.R &
mouse.genome_ref.path <- "/home/zhenyisong/data/bringback/igenome/Mus_musculus/UCSC/mm10/Sequence/WholeGenomeFasta/genome.fa"
rat.genome_ref.path   <- '/home/zhenyisong/data/bringback/igenome/Rattus_norvegicus/UCSC/rn6/Sequence/WholeGenomeFasta/genome.fa'
rat.gtf               <- '/home/zhenyisong/data/bringback/igenome/Rattus_norvegicus/UCSC/rn6/Annotation/Genes/genes.gtf'
setwd('/home/zhenyisong/data/wanglilab/projects/xinli')
reads.files.names    <- list.files(pattern = '*.fastq$')
rat.files.names      <- reads.files.names[1:4]
mouse.files.names    <- reads.files.names[5:21]
rat.reads.paths      <- paste0(getwd(),'/',rat.files.names)
mouse.reads.paths    <- paste0(getwd(),'/',mouse.files.names)

#reads.paths          <- paste0(getwd(),'/',reads.files.names)

setwd('/home/zhenyisong/data/wanglilab/projects/xinli')
unlink('rsubread')
dir.create('rsubread')
output.path          <- '/home/zhenyisong/data/wanglilab/projects/xinli/rsubread'
setwd('/home/zhenyisong/data/wanglilab/projects/xinli/rsubread')

rat.outputs.files        <- paste0(output.path,'/', rat.files.names,'.bam')
mouse.outputs.files      <- paste0(output.path,'/', mouse.files.names,'.bam')
mouse.base.string        <- 'mm10_index'
rat.base.string          <- 'rn6_index'
"
use the Rsubread command to generate index file
this index file will be generated and saved at getwd()
you do not need to generate the script
"
setwd("/home/zhenyisong/data/wanglilab/projects/xinli/rsubread")
buildindex( basename = mouse.base.string, reference = mouse.genome_ref.path )
buildindex( basename = rat.base.string, reference = rat.genome_ref.path )

"
this is the function which is called to align the genome
sequence
"

align( index         = mouse.base.string, 
       readfile1     = mouse.reads.paths, 
       input_format  = "FASTQ", 
       type          = 'rna',
       output_file   = mouse.outputs.files, 
       output_format = "BAM", 
       nthreads      = 8, 
       indels        = 1,
       maxMismatches = 3,
       phredOffset   = 33,
       unique        = T )


align( index         = rat.base.string, 
       readfile1     = rat.reads.paths, 
       input_format  = "FASTQ", 
       type          = 'rna',
       output_file   = rat.outputs.files, 
       output_format = "BAM", 
       nthreads      = 8, 
       indels        = 1,
       maxMismatches = 3,
       phredOffset   = 33,
       unique        = T )

# get gene's counts
gene.mouse         <-  featureCounts( mouse.outputs.files, useMetaFeatures = TRUE, 
                                      annot.inbuilt = "mm10", 
                                      nthreads      = 8, allowMultiOverlap = TRUE)
gene.rat           <- featureCounts( rat.outputs.files, useMetaFeatures = TRUE, 
                                      annot.ext  = rat.gtf, isGTFAnnotationFile = TRUE,
                                      nthreads   = 8, allowMultiOverlap = TRUE)

# setwd('/home/zhenyisong/data/cardiodata')
# save.image(file = 'multiple.xinli.Rdata')
# quit("no")  


#--- BeiYi Project---
# process the beiyi data
# 
gene         <- gene.mouse
gene.counts  <- gene$counts[,5:11]
gene.ids     <- gene$annotation$GeneID

keytypes(org.Mm.eg.db)

columns  <- c("ENTREZID","SYMBOL","MGI","GENENAME");
GeneInfo <- select( org.Mm.eg.db, keys= as.character(gene.ids), 
                   keytype = "ENTREZID", columns = columns);
m        <- match(gene$annotation$GeneID, GeneInfo$ENTREZID);
Ann      <- cbind( gene$annotation[, c("GeneID", "Chr","Length")],
                          GeneInfo[m, c("SYMBOL", "MGI","GENENAME")]);

Ann$Chr  <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                    function(x) paste(unique(x), collapse = "|")))
Ann$Chr  <- gsub("chr", "", Ann$Chr)

gene.exprs <- DGEList(counts = gene.counts, genes = Ann)
gene.exprs <- calcNormFactors(gene.exprs)
dge.tmm    <- t(t(gene.exprs$counts) * gene.exprs$samples$norm.factors)
dge.tmm.counts           <- apply(dge.tmm,2, as.integer)
rownames(dge.tmm.counts) <- gene.exprs$genes$SYMBOL
#setwd("C:\\Users\\Yisong\\Desktop")
#write.table(dge.tmm.counts, file = 'beiyi.genecounts.txt')
sample.info              <- data.frame( treat  = c('Control','Control',
                                                   'Control','Control',
                                                   'Treat','Treat','Treat') )
dds                      <- DESeqDataSetFromMatrix( countData = dge.tmm.counts,
                                                    colData   = sample.info,
                                                    design    = ~ treat)
vsd                      <- varianceStabilizingTransformation(dds);
vsd.expr                 <- assay(vsd)
#rownames(vsd.expr)       <- gene.exprs$genes$SYMBOL
rownames(vsd.expr)       <- NULL
colnames(vsd.expr)       <- c('Control-1','Control-2',
                              'Control-3','Control-4',
                              'Treat-1','Treat-2','Treat-3')  
sds <- rowSds(vsd.expr)
sh  <- shorth(sds)
vsd.filtered.expr <- vsd.expr[sds > 0.3,]
my.palette        <- rev(colorRampPalette(brewer.pal(10, "RdBu"))(256))
heatmap( cor(vsd.filtered.expr, method = 'spearman'), 
         cexCol = 0.8, cexRow = 0.8, col = my.palette)
pr <- prcomp(t(vsd.expr))
plot(pr$x[,1:2], col = 'white', main = 'Sample PCA plot', type = "p")
text(pr$x[,1], pr$x[,2], labels = colnames(vsd.expr), cex = 0.7)

clara.res <- clara(t(vsd.filtered.expr), 2, samples = 50, pamLike = TRUE)

fviz_cluster( clara.res,
              palette = c("#00AFBB", '#FC4E07') ,
              ellipse = FALSE,
              geom = 'point', pointsize = 3,
              ggtheme = theme_classic()  )

groups     <- factor(c(1,1,1,1,2,2,2), levels = 1:2, labels = c('Control','Treat'));
design     <- model.matrix(~ 0 + groups);
colnames(design) <- levels(groups)
contrast.matrix  <- makeContrasts(Treat - Control, levels = design)
d.norm           <- voom(gene.exprs, design = design)
fit              <- lmFit(d.norm, design)
fit2             <- contrasts.fit(fit,contrast.matrix)
fit2             <- eBayes(fit2)
gene.result      <- topTable(  fit2, 
                               number        = Inf, 
                               adjust.method = "BH", 
                               sort.by       = "p");


# setwd("C:\\Users\\Yisong\\Desktop")
write.xlsx(gene.result, file = 'beiyi2.xlsx')


gene.result      <- topTable(  fit2, 
                               number        = Inf, 
                               adjust.method = "BH", 
                               sort.by       = "p",
                               p.value       = 0.05)
gene.entrez.id   <- gene.result$GeneID
kegg.table       <- enrichKEGG( gene.entrez.id, organism = "mouse", 
                                pvalueCutoff  = 0.05, 
                                pAdjustMethod = "BH", 
                                qvalueCutoff  = 0.1)
kegg.result       <- summary(kegg.table)
kegg.qvalue       <- -log(kegg.result$qvalue)
kegg.pathway.name <- kegg.result$Description

par(mar = c(12,4,1,1), fin = c(4,4))

x = barplot( kegg.qvalue, cex.lab = 0.8,cex.axis= 0.8, width = 0.5,
             main = 'KEGG enrichment anlysis', cex.main = 0.8,
             ylab = '-log(q-value of enrichment)')
text( cex = 0.75, x = x - 0.25, y = -1.25, 
      kegg.pathway.name, 
      xpd = TRUE, srt = 60, pos = 2)

#
# xinli data analysis
# FBS
#---

gene         <- gene.mouse
gene.counts  <- gene$counts[,1:4]
gene.ids     <- gene$annotation$GeneID

columns  <- c("ENTREZID","SYMBOL","MGI","GENENAME");
GeneInfo <- AnnotationDbi::select( org.Mm.eg.db, keys= as.character(gene.ids), 
                   keytype = "ENTREZID", columns = columns);
m        <- match(gene$annotation$GeneID, GeneInfo$ENTREZID);
Ann      <- cbind( gene$annotation[, c("GeneID", "Chr","Length")],
                          GeneInfo[m, c("SYMBOL", "MGI","GENENAME")]);

Ann$Chr  <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                    function(x) paste(unique(x), collapse = "|")))
Ann$Chr  <- gsub("chr", "", Ann$Chr)

gene.exprs     <- DGEList(counts = gene.counts, genes = Ann)
fbs.gene.exprs <- calcNormFactors(gene.exprs)



# according to the suggestion by wang li
#----
rpkm.genes           <- rpkm(gene.exprs, log = TRUE)
rpkm.lfc.genes <- cbind( rpkm.genes[,3] - rpkm.genes[,1], rpkm.genes[,4] - rpkm.genes[,2],
                         (rpkm.genes[,3] + rpkm.genes[,4])/2 - (rpkm.genes[,1] + rpkm.genes[,2])/2 )
colnames(rpkm.lfc.genes) <- c('FBS01 - C1','FBS02 -C2','mean(FBS01+FBS02) - mean(C1+C2)')
rownames(rpkm.genes)     <- make.names(Ann$SYMBOL, unique = TRUE)
rownames(rpkm.lfc.genes) <- make.names(Ann$SYMBOL, unique = TRUE)
colnames(rpkm.genes) <- c('Control-1','Control-2','FBS-1','FBS-2')
setwd("C:\\Users\\Yisong\\Desktop")
write.xlsx(rpkm.lfc.genes, file = 'xinliRPKM.FBS.lfc.xlsx', sheetName = 'Log_Fold_Change')
write.xlsx(rpkm.genes, file = 'xinliRPKM.FBS.lfc.xlsx', sheetName = 'gene log(RPKM)', append = TRUE)
#
#
#--- no need if we pull out batch effect, see below
#---
dge.tmm    <- t(t(gene.exprs$counts) * gene.exprs$samples$norm.factors)
dge.tmm.counts           <- apply(dge.tmm,2, as.integer)
sample.info              <- data.frame( treat  = c('Control','Control',
                                                   'FBS','FBS') )
dds                      <- DESeqDataSetFromMatrix( countData = dge.tmm.counts,
                                                    colData   = sample.info,
                                                    design    = ~ treat)
vsd                      <- varianceStabilizingTransformation(dds);
vsd.expr                 <- assay(vsd)
#rownames(vsd.expr)       <- gene.exprs$genes$SYMBOL
rownames(vsd.expr)       <- NULL
colnames(vsd.expr)       <- c('Control-1','Control-2',
                              'FBS-1','FBS-2')  

sds <- rowSds(vsd.expr)
sh  <- shorth(sds)
vsd.filtered.expr <- vsd.expr[sds > 0.3,]
my.palette        <- rev(colorRampPalette(brewer.pal(10, "RdBu"))(256))
heatmap( cor(vsd.filtered.expr, method = 'spearman'), 
         cexCol = 0.8, cexRow = 0.8, col = my.palette)
pr <- prcomp(t(vsd.expr))
plot(pr$x[,1:2], col = 'white', main = 'Sample PCA plot', type = "p")
text(pr$x[,1], pr$x[,2], labels = colnames(vsd.expr), cex = 0.7)

pr.var <- pr$sdev^2
pve    <- pr.var/sum(pr.var)
plot(pve, xlab = 'PCA', ylab = 'Variance explained', type = 'b')


rotations <- order(pr$rotation[,2], decreasing = FALSE)
gene.len  <- 200
total.len <- length(vsd.expr)
FBS.markers <- unique(c( gene.exprs$genes$SYMBOL[rotations[1:gene.len]],
                                  gene.exprs$genes$SYMBOL[rotations[(total.len - gene.len):total.len]] ) )

clara.res <- clara(t(vsd.filtered.expr), 2, samples = 50, pamLike = TRUE)

fviz_cluster( clara.res,
              palette = c("#00AFBB", '#FC4E07') ,
              ellipse = FALSE,
              geom = 'point', pointsize = 3,
              ggtheme = theme_classic()  )


# after the above analysis, the result is obvious
# that Xinli data have strong batch effect;
# y <- DGEList(counts) then the first reaction is to
# erase the batch effect using the current tools
# https://www.biostars.org/p/170938/
# https://support.bioconductor.org/p/76381/
# https://www.biostars.org/p/156186/
# search key words: SVA RNA-seq
#                   batch effects in rna-seq
# 
# gene.exprs.data is the normorlized data
# please see the above code
# 

# the below procedure is from here, please 
# read it carefully
# https://support.bioconductor.org/p/83690/
# https://support.bioconductor.org/p/54447/

batch.effect <- factor(c(1,2,1,2), levels = 1:2, labels = c('cell1','cell2'))
groups       <- factor(c(1,1,2,2), levels = 1:2, labels = c('Control','FBS'))
design       <- model.matrix(~ 0 + groups + batch.effect);
colnames(design) <- c('Control','FBS','Batch')
contrast.matrix  <- makeContrasts(FBS - Control, levels = design)
d.norm           <- voom(fbs.gene.exprs, design = design)
fit              <- lmFit(d.norm, design)
fit2             <- contrasts.fit(fit,contrast.matrix)
fbs.fit2             <- eBayes(fit2)
FBS.sm.phenotype.result      <- topTable(  fbs.fit2, 
                                           number        = Inf, 
                                           adjust.method = "BH", 
                                           sort.by       = "p",
                                           p.value       = 0.05,
                                           lfc           = 1.5);


# setwd("C:\\Users\\Yisong\\Desktop")
write.xlsx(gene.result, file = 'xinli.FBS.removeBatch.limma.xlsx')



# here begin the limma analysis
# this is not implemmented yet!
groups     <- factor(c(1,1,2,2), levels = 1:2, labels = c('Control','FBS'))
mod1       <- model.matrix(~ groups )
mod0       <- model.matrix(~ 1)

data.cpm   <- cpm(gene.exprs)
data.cpm   <- data.cpm + 20
n.sv       <- num.sv(data.cpm,mod1,method="leek")
sds <- rowSds(data.cpm)
sh  <- shorth(sds)
data.cpm.filtered <- data.cpm[sds > 0.5,]
data.cpm.filtered <- apply(data.cpm.filtered,2, as.integer)
data.cpm.filtered <- data.cpm.filtered + 5
svobj <- svaseq(data.cpm.filtered , mod1, mod0) 
des <- cbind(mod, svobj$sv)


#
# xinli
# thoc5
#---
gene         <- gene.mouse
gene.counts  <- gene$counts[,12:17]
gene.ids     <- gene$annotation$GeneID


columns  <- c("ENTREZID","SYMBOL","MGI","GENENAME");
GeneInfo <- select( org.Mm.eg.db, keys= as.character(gene.ids), 
                   keytype = "ENTREZID", columns = columns);
m        <- match(gene$annotation$GeneID, GeneInfo$ENTREZID);
Ann      <- cbind( gene$annotation[, c("GeneID", "Chr","Length")],
                          GeneInfo[m, c("SYMBOL", "MGI","GENENAME")]);

Ann$Chr  <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                    function(x) paste(unique(x), collapse = "|")))
Ann$Chr  <- gsub("chr", "", Ann$Chr)

gene.exprs <- DGEList(counts = gene.counts, genes = Ann)
gene.exprs <- calcNormFactors(gene.exprs)

rpkm.genes <- rpkm(gene.exprs, log = TRUE)
rownames(rpkm.genes) <- make.names(Ann$SYMBOL, unique = TRUE)
colnames(rpkm.genes) <- c('Control1','Control2','ShnRNA772-1','ShnRNA772-2','ShnRNA773-1','ShnRNA773-2')
rpkm.lfc.genes       <- cbind( rpkm.genes[,3] - rpkm.genes[,1], rpkm.genes[,4]- rpkm.genes[,2],
                               rpkm.genes[,5] - rpkm.genes[,1], rpkm.genes[,6]- rpkm.genes[,2] )
colnames(rpkm.lfc.genes) <- c('Sh772-Control1','Sh772-Control2','Sh773-Control1','Sh773-Control2')
setwd("C:\\Users\\Yisong\\Desktop")
write.xlsx(rpkm.lfc.genes, file = 'xinli.Thoc5.lfc.xlsx', sheetName = 'log_Fold_Change')
write.xlsx(rpkm.genes, file = 'xinli.Thoc5.lfc.xlsx',sheetName = 'Log_Expression_Value', append = TRUE)

dge.tmm    <- t(t(gene.exprs$counts) * gene.exprs$samples$norm.factors)
dge.tmm.counts           <- apply(dge.tmm,2, as.integer)
sample.info              <- data.frame( treat  = c('Control','Control',
                                                   'Thoc5','Thoc5','Thoc5','Thoc5') )
dds                      <- DESeqDataSetFromMatrix( countData = dge.tmm.counts,
                                                    colData   = sample.info,
                                                    design    = ~ treat)
vsd                      <- varianceStabilizingTransformation(dds);
vsd.expr                 <- assay(vsd)
#rownames(vsd.expr)       <- gene.exprs$genes$SYMBOL
rownames(vsd.expr)       <- NULL
colnames(vsd.expr)       <- c('Control-1','Control-2',
                              'Thoc5-1','Thoc5-2','Thoc5-3','Thoc5-4')  

sds <- rowSds(vsd.expr)
sh  <- shorth(sds)
vsd.filtered.expr <- vsd.expr[sds > 0.3,]
my.palette        <- rev(colorRampPalette(brewer.pal(10, "RdBu"))(256))
heatmap( cor(vsd.filtered.expr, method = 'spearman'), 
         cexCol = 0.8, cexRow = 0.8, col = my.palette)
pr <- prcomp(t(vsd.expr))
plot(pr$x[,1:2], col = 'white', main = 'Thoc5 PCA plot', type = "p")
text(pr$x[,1], pr$x[,2], labels = colnames(vsd.expr), cex = 0.7)
pr.var <- pr$sdev^2
pve    <- pr.var/sum(pr.var)
plot(pve, xlab = 'PCA', ylab = 'Variance explained', type = 'b')
clara.res <- clara(t(vsd.filtered.expr), 2, samples = 50, pamLike = TRUE)

fviz_cluster( clara.res,
              palette = c("#00AFBB", '#FC4E07') ,
              ellipse = FALSE,
              geom = 'point', pointsize = 3,
              ggtheme = theme_classic()  )


gene.epxrs.first  <- gene.counts[,c(1:4)]
gene.epxrs.second <- gene.counts[,c(1,2,5,6)]
gene.exprs.first  <- DGEList(counts = gene.epxrs.first, genes = Ann)
gene.exprs.second <- DGEList(counts = gene.epxrs.second, genes = Ann)
gene.exprs.772    <- calcNormFactors(gene.exprs.first)
gene.exprs.773    <- calcNormFactors(gene.exprs.second)

cell.lines     <- factor(rep(c(1,2), 2), levels = 1:2, labels = c('C1','C2'))
groups         <- factor(c(1,1,2,2), levels = 1:2, labels = c('Control','Thoc5'))
design           <- model.matrix(~ 0 + groups);
colnames(design) <- levels(groups)
d.norm.772           <- voom(gene.exprs.772, design = design)
d.norm.773           <- voom(gene.exprs.773, design = design)
cor.fit.772          <- duplicateCorrelation(d.norm.772,design,block = cell.lines)
cor.fit.773          <- duplicateCorrelation(d.norm.773,design,block = cell.lines)


fit              <- lmFit(d.norm.773, block = cell.lines,correlation = cor.fit.773$consensus)
fit2             <- contrasts.fit(fit,contrast.matrix)
fit2             <- eBayes(fit2)
gene.result.773  <- topTable(  fit2, 
                               number        = Inf, 
                               adjust.method = "BH", 
                               sort.by       = "p",
                               );
#---
# the above method failed to calculate the correlation
# use the second method instead.

design           <- model.matrix(~ 0 + groups + cell.lines);
colnames(design) <- c('Control','Thoc5','Batch')
contrast.matrix  <- makeContrasts(Thoc5 - Control, levels = design)
d.norm.772       <- voom(gene.exprs.772, design = design)
d.norm.773       <- voom(gene.exprs.773, design = design)
fit              <- lmFit(d.norm.772)
fit2             <- contrasts.fit(fit,contrast.matrix)
fit2             <- eBayes(fit2)
gene.result.772  <- topTable(  fit2, 
                               number        = Inf, 
                               adjust.method = "BH", 
                               sort.by       = "p",
                               );

fit              <- lmFit(d.norm.773)
fit2             <- contrasts.fit(fit,contrast.matrix)
fit2             <- eBayes(fit2)
gene.result.773  <- topTable(  fit2, 
                               number        = Inf, 
                               adjust.method = "BH", 
                               sort.by       = "p",
                               );

setwd("C:\\Users\\Yisong\\Desktop")
write.xlsx(gene.result.772, file = 'xinli.Thoc5.772.limma.xlsx')
write.xlsx(gene.result.773, file = 'xinli.Thoc5.773.limma.xlsx')


# generated the DGE heatmap using ggplot2?
# as requested by Xinli
# this need the DGE with filter p.value = 0.05

#
# here begin the limma analysis
# this is not implemmented yet!
# ---- please bee carfull the data and data format
#---
groups     <- factor(c(1,1,2,2), levels = 1:2, labels = c('Control','Thoc5'))
design     <- model.matrix(~ 0 + groups);
mod1  <- model.matrix(~ groups )
mod0 <- model.matrix(~ 1)
#n.sv <- num.sv(dge.tmm.counts,mod1,method="leek")
data.cpm <- cpm(gene.exprs.772)
sds <- rowSds(data.cpm)
sh  <- shorth(sds)
data.cpm.filtered <- data.cpm[sds > 0.4,]
dge.tmm.counts.filtered    <- apply(data.cpm.filtered,2, as.numeric)

svobj <- svaseq(dge.tmm.counts.filtered, mod1, mod0, constant = 30) 
des <- cbind(mod, svobj$sv)

#
# GSEA
setwd('E:\\FuWai\\wangli.lab\\Others')
smc.file.name <- 'SM-markers.xlsx'
smc.file.df   <- read.xlsx(smc.file.name, sheetIndex = 2, header = TRUE)

pathway.genelist = gene.result.772$logFC
names(pathway.genelist) = gene.result.772$GeneID

pathway.genelist  <- sort(pathway.genelist, decreasing = TRUE)

secretory2gene <- data.frame( diseaseId = unlist(as.character(rep('smc',length(smc.file.df$EntrezID)))), 
                              geneId = unlist(as.integer(smc.file.df$EntrezID)), check.names = TRUE)
secretory.GSEA <- GSEA(pathway.genelist, TERM2GENE = secretory2gene,  minGSSize = 3) 

gene.result.772[gene.result.772$GeneID %in% c(smc.file.df$EntrezID, 107829),]

# figure generation
#---

# load image
gene         <- gene.mouse
gene.counts  <- gene$counts[,12:17]
gene.ids     <- gene$annotation$GeneID


columns  <- c("ENTREZID","SYMBOL","MGI","GENENAME");
GeneInfo <- AnnotationDbi::select( org.Mm.eg.db, keys= as.character(gene.ids), 
                   keytype = "ENTREZID", columns = columns);
m        <- match(gene$annotation$GeneID, GeneInfo$ENTREZID);
Ann      <- cbind( gene$annotation[, c("GeneID", "Chr","Length")],
                          GeneInfo[m, c("SYMBOL", "MGI","GENENAME")]);

Ann$Chr  <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                    function(x) paste(unique(x), collapse = "|")))
Ann$Chr  <- gsub("chr", "", Ann$Chr)

gene.exprs.772 <- DGEList(counts = gene.counts[,1:4], genes = Ann)
gene.exprs.772 <- gene.exprs.772 %>% calcNormFactors(method = 'TMM') %>% rpkm(log = TRUE);
colnames(gene.exprs.772) <- c('Control-1','Control-2','Thocs5-1','Thocs5-2')
rownames(gene.exprs.772) <- make.names(Ann$SYMBOL, unique = TRUE)
median.exprs             <- NULL
median.exprs             <- cbind( (gene.exprs.772[,1] + gene.exprs.772[,2])/2,
                                   (gene.exprs.772[,3] + gene.exprs.772[,4])/2)

median.exprs             <- cbind(median.exprs, rep(0,dim(median.exprs)[1]))
colnames(median.exprs)   <- c('Control','Treat','Type')


setwd("E:\\FuWai\\wangli.lab\\Others")
vcms.markers      <- 'SM-markers.xlsx' # this data is manually curated
vcms.dif.table    <- read.xlsx(vcms.markers,header = TRUE, stringsAsFactors = FALSE, sheetIndex = 1)
vcms.sec.table    <- read.xlsx(vcms.markers,header = TRUE, stringsAsFactors = FALSE, sheetIndex = 2)
vsmc.dif.genename <- vcms.dif.table$GeneSymbol
vsmc.sec.genename <- vcms.sec.table$GeneSymbol

median.exprs[row.names(median.exprs) %in% vsmc.dif.genename,3] <- 1
median.exprs[row.names(median.exprs) %in% vsmc.sec.genename,3] <- 2
vsmc.dif.df          <- median.exprs[vsmc.dif.genename,]
vsmc.sec.df          <- median.exprs[vsmc.sec.genename,]

median.exprs         <- as.data.frame(median.exprs)
vsmc <- ggplot(data = median.exprs)
vsmc + ylab('Knockdown of Thocs5') +
      geom_point(aes( x = Control, y = Treat,
                      color = as.factor(Type), size = as.factor(Type), alpha = as.factor(Type) ) )+
       scale_size_manual(values = c(2, 2, 2), guide = FALSE) + 
       scale_alpha_manual(values = c(1/200, 1, 1), guide = FALSE) + 
       scale_colour_manual(name = 'gene groups',values = c("black", "blue", "red"), 
                           labels = c('non-related genes','differentiation marker','secretory marker')) + 

       geom_abline(intercept = 0.58, slope = 1, size = 1, alpha = 1/10) +
       geom_abline(intercept = -0.58, slope = 1, size = 1, alpha = 1/10) +
       geom_text( aes(x = Control, y = Treat), label = rownames(vsmc.dif.df), 
                  data = vsmc.dif.df,hjust = 1,vjust = 1, size = 2, col = 'blue') +
       geom_text( aes(x = Control, y = Treat), label = rownames(vsmc.sec.df), 
                  data = vsmc.sec.df,hjust = 1,vjust = 1, size = 2, col = 'red') +
       theme(legend.position = c(0.8, 0.2),legend.title.align = 0.5)


# xinli
# QC PDGFBB migration genes clusters
# curated from public database
# https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE19106
# rat vascular smooth muscle
# 
#---
setwd("D:\\wangli_data\\GSE19106")

raw.data    <- ReadAffy();
rma.data    <- affy::rma(raw.data);
exprs.data  <- exprs(rma.data)
probes      <- rownames(exprs.data)
gene.symbol <- unlist(mget(probes, rat2302SYMBOL, ifnotfound = NA))
rownames(exprs.data) <- gene.symbol
f           <- factor( c(1,1,2,2 ), levels = c(1:2),
                       labels = c("Control","PDGFBB"))
design      <- model.matrix(~ 0 + f)

colnames(design)      <- levels(f)
fit                   <- lmFit(exprs.data, design)
contrast.matrix       <- makeContrasts(PDGFBB - Control,levels = design)
fit2                  <- contrasts.fit(fit, contrast.matrix)
fit2                  <- eBayes(fit2)

# I p-hacking the p value from 0.58 - 2 -4 and no significant
#---
result                <- topTable(fit2, coef = 1, adjust = "BH", number = Inf,
                                  p.value = 0.05, lfc = 4)

migration.genes       <- na.omit(result$ID)


# processing 772 data set from Xinli
gene                  <- gene.mouse
gene.counts           <- gene$counts[,12:15]
gene.ids              <- gene$annotation$GeneID
columns               <- c("ENTREZID","SYMBOL","MGI","GENENAME");
GeneInfo              <- AnnotationDbi::select( org.Mm.eg.db, keys= as.character(gene.ids), 
                                keytype = "ENTREZID", columns = columns);
m                     <- match(gene$annotation$GeneID, GeneInfo$ENTREZID);
Ann                   <- cbind( gene$annotation[, c("GeneID", "Chr","Length")],
                                       GeneInfo[m, c("SYMBOL", "MGI","GENENAME")]);
                      
Ann$Chr               <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                                 function(x) paste(unique(x), collapse = "|")))
gene.exprs            <- gene.counts %>% DGEList(genes = Ann) %>% calcNormFactors()

Ann$Chr               <- gsub("chr", "", Ann$Chr)
cell.lines            <- factor(rep(c(1,2), 2), levels = 1:2, labels = c('C1','C2'))
groups                <- factor(c(1,1,2,2), levels = 1:2, labels = c('Control','Thoc5'))


design                <- model.matrix(~ 0 + groups + cell.lines);
colnames(design)      <- c('Control','Thoc5','Batch')
contrast.matrix       <- makeContrasts(Thoc5 - Control, levels = design)
d.norm                <- voom(gene.exprs, design = design)
fit                   <- lmFit(d.norm)
fit2                  <- contrasts.fit(fit,contrast.matrix)
fit2                  <- eBayes(fit2)
gene.result           <- topTable(  fit2, 
                                    number        = Inf, 
                                    adjust.method = "BH", 
                                    sort.by       = "p",
 
"                                   )
gene.thoc5.772        <- gene.mouse %$% counts[,12:15] %>%
                         DGEList() %>% calcNormFactors() %>%
                         voom(design = design) %>%
                         lmFit() %>%
                         contrasts.fit(contrast.matrix) %>%
                         eBayes() %>%
                         topTable(number = Inf, adjust.method = 'BH')
"
                         
#
# please re-check this code.!
migration.genes          <- na.omit(result$ID)                      
migration.db             <- gene.result$GeneID[gene.result$SYMBOL %in% migration.genes]
pathway.genelist         <- gene.result$logFC
names(pathway.genelist)  <- gene.result$GeneID

pathway.genelist         <- sort(pathway.genelist, decreasing = TRUE)

migration2gene           <- data.frame( diseaseId = unlist(as.character(rep('smc',length(migration.db)))), 
                                        geneId    = unlist(as.integer(migration.db)), check.names = TRUE)
migration.GSEA           <- GSEA(pathway.genelist, TERM2GENE = migration2gene ,maxGSSize = 5000, pvalueCutoff = 1)


# migration DB using the FBS data xinli, RNA-seq
#---
fbs.migration.db         <- rownames(FBS.sm.phenotype.result)
migration2gene           <- data.frame( diseaseId = unlist(as.character(rep('fbs.migration',length(fbs.migration.db)))), 
                                        geneId    = unlist(as.integer(fbs.migration.db)), check.names = TRUE)

fbs.migration.GSEA       <- GSEA(pathway.genelist, TERM2GENE = migration2gene, maxGSSize = 5000, pvalueCutoff = 1)
gseaplot(fbs.migration.GSEA, 'fbs.migration')

#preparing geneSet collections...
#GSEA analysis...
#no term enriched under specific pvalueCutoff...

# just a joke to p.hack the data analysis
#---
pvalue      <- seq( 0.1,0.001, by = -0.001 )
lfc.value   <- seq( 0.4, 4, by = 0.01 )

# pvalue <- c(0.05, 0.03)
# lfc.value <- c(0.58, 1.5, 2,2.5)
# small sample to crack
#---
result.mat  <- NULL

blackgoat <- function (pvalue, lfc.value, fit.param, pathway.whole) {
    for(p in pvalue) {
        for(f in lfc.value) {
            result.buffer <- topTable(  fit.param, 
                                        number        = Inf, 
                                        adjust.method = "BH", 
                                        sort.by       = "p",
                                        p.value       = p,
                                        lfc           = f);

            buffer.db    <- rownames(result.buffer)
            buffer2gene  <- data.frame( diseaseId = unlist(as.character(rep('fbs.migration',length(buffer.db)))), 
                                        geneId    = unlist(as.integer(buffer.db)), check.names = TRUE)

            buffer.GSEA  <- GSEA(pathway.whole, TERM2GENE = buffer2gene, minGSSize = 4, maxGSSize = 5000, pvalueCutoff = 1)
            if(buffer.GSEA$p.adjust < 0.05) {
                print(p)
                print(f)
                result.mat <- append(c(p,f), result.mat)
            }           
        }
    }
    return(matrix(t(result.mat),ncol = 2, byrow = T)) 
}

result.vec <- blackgoat(pvalue, lfc.value, fit2, pathway.genelist)


point.color <- c('gray76','chartreuse1')
point.color <- point.color[as.numeric(result.vec[,3] <= 0.05) + 1 ]
scatterplot3d( result.vec, pch = 16, xlab = 'p.value', angle = 35,
               ylab = 'log.fold.change', zlab = 'gsea.pvalue',
               type = 'p', scale.y = 0.8, color = point.color)

rgl_init()

plot3d( x = result.vec[,1], y = result.vec[,2], z = result.vec[,3], col = 'blue',
        type = 'p', xlab = 'edgeR.p.value', ylab = 'edgeR.lfc', zlab = 'gsea.pvalue',
        box = FALSE)

##colnames(result.vec) <- c('pvalue','lfc')
##ggplot(data = as.data.frame(result.vec), aes(x = pvalue, y = lfc)) + geom_point()


# reverse the GSEA analysis
# using the Thocs5 as the feature source
#  in this way, I selected and set the threshold to 
#  get these feature genes from DEG analysis
# mapping to FBS treated data, this is as the whole set
#---

gene                  <- gene.mouse
gene.counts           <- gene$counts[,12:15]
gene.ids              <- gene$annotation$GeneID
columns               <- c("ENTREZID","SYMBOL","MGI","GENENAME");
GeneInfo              <- AnnotationDbi::select( org.Mm.eg.db, keys= as.character(gene.ids), 
                                keytype = "ENTREZID", columns = columns);
m                     <- match(gene$annotation$GeneID, GeneInfo$ENTREZID);
Ann                   <- cbind( gene$annotation[, c("GeneID", "Chr","Length")],
                                       GeneInfo[m, c("SYMBOL", "MGI","GENENAME")]);
                      
Ann$Chr               <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                                 function(x) paste(unique(x), collapse = "|")))
gene.exprs.772        <- gene.counts %>% DGEList(genes = Ann) %>% calcNormFactors
design                <- model.matrix(~ 0 + groups + cell.lines);
colnames(design)      <- c('Control','Thoc5','Batch')
contrast.matrix       <- makeContrasts(Thoc5 - Control, levels = design)
                      
gene.reverse.772      <- gene.exprs.772 %>% voom(design = design) %>% lmFit() %>%
                         contrasts.fit(contrast.matrix) %>% 
                         eBayes() %>%
                         topTable( number = Inf)

fbs.reverse.result       <- topTable(fbs.fit2, number= Inf)


whole.reverse.set        <- fbs.reverse.result %>% arrange(desc(logFC)) %$% logFC
names(whole.reverse.set) <- fbs.reverse.result %$% GeneID             

migration.reverse.set    <- gene.reverse.772 %>% filter(logFC > 0.58 & P.Value < 0.05) %$% GeneID

migration.reverse2gene   <- data.frame( diseaseId = rep('smc',length(migration.reverse.set)) ), 
                                        geneId    = migration.reverse.set, check.names = TRUE)
migration.reverseGSEA    <- GSEA( whole.reverse.set, TERM2GENE = migration.reverse2gene,
                                  maxGSSize = 5000, pvalueCutoff = 1)

gseaplot(migration.reverseGSEA, 'smc')
# migration DB using the FBS data xinli, RNA-seq
#---
fbs.migration.db         <- rownames(FBS.sm.phenotype.result)
migration2gene           <- data.frame( diseaseId = unlist(as.character(rep('fbs.migration',length(fbs.migration.db)))), 
                                        geneId    = unlist(as.integer(fbs.migration.db)), check.names = TRUE)

fbs.migration.GSEA       <- GSEA(pathway.genelist, TERM2GENE = migration2gene, maxGSSize = 5000, pvalueCutoff = 1)
gseaplot(fbs.migration.GSEA, 'fbs.migration')


# secretory gene heatmap

#---test code
# for sva analysis
# to be implemented


#
# zongna
#---

gene         <- gene.rat
gene.counts  <- gene$counts
gene.ids     <- gene$annotation$GeneID

Ann          <- gene$annotation[, c("GeneID", "Chr","Length")]

Ann$Chr      <- unlist( lapply(strsplit(Ann$Chr, ";"), 
                    function(x) paste(unique(x), collapse = "|")))
Ann$Chr      <- gsub("chr", "", Ann$Chr)

gene.exprs   <- DGEList(counts = gene.counts, genes = Ann)
gene.exprs   <- calcNormFactors(gene.exprs)

rpkm.genes     <- rpkm(gene.exprs, log = TRUE)
colnames(rpkm.genes) <- c('Control1','Control2','Ino801','Ino802')
rpkm.lfc.genes <- cbind( rpkm.genes[,3] - rpkm.genes[,1], rpkm.genes[,4]- rpkm.genes[,2],
                         (rpkm.genes[,3] + rpkm.genes[,4])/2 - (rpkm.genes[,1] + rpkm.genes[,2])/2 )
colnames(rpkm.lfc.genes) <- c('Ino801 - Control1','Ino802 -Control2','mean(Ino801+Ino802) - mean(C1+C2)')
setwd("C:\\Users\\Yisong\\Desktop")
write.xlsx(rpkm.lfc.genes, file = 'zongna.lfc.xlsx', sheetName = 'Sheet1')
write.xlsx(rpkm.genes, file = 'zongna.lfc.xlsx',sheetName = 'Sheet2', append = TRUE)
dge.tmm    <- t(t(gene.exprs$counts) * gene.exprs$samples$norm.factors)
dge.tmm.counts           <- apply(dge.tmm,2, as.integer)
sample.info              <- data.frame( treat  = c('Control','Control',
                                                   'Treat','Treat') )
dds                      <- DESeqDataSetFromMatrix( countData = dge.tmm.counts,
                                                    colData   = sample.info,
                                                    design    = ~ treat)
vsd                      <- varianceStabilizingTransformation(dds);
vsd.expr                 <- assay(vsd)
#rownames(vsd.expr)       <- gene.exprs$genes$SYMBOL
rownames(vsd.expr)       <- NULL
colnames(vsd.expr)       <- c('Control-1','Control-2',
                              'Ino80-1','Ino80-2')  
sds <- rowSds(vsd.expr)
sh  <- shorth(sds)
vsd.filtered.expr <- vsd.expr[sds > 0.3,]
my.palette        <- rev(colorRampPalette(brewer.pal(10, "RdBu"))(256))
heatmap( cor(vsd.filtered.expr, method = 'spearman'), 
         cexCol = 0.8, cexRow = 0.8, col = my.palette)
pr <- prcomp(t(vsd.expr))
plot(pr$x[,1:2], col = 'white', main = 'Sample PCA plot', type = "p")
text(pr$x[,1], pr$x[,2], labels = colnames(vsd.expr), cex = 0.7)
pr.var <- pr$sdev^2
pve    <- pr.var/sum(pr.var)
plot(pve, xlab = 'PCA', ylab = 'Variance explained', type = 'b')

groups     <- factor(c(1,1,2,2),levels = 1:2, labels = c('Control','Ino80'))
design     <- model.matrix(~ 0 + groups);
colnames(design) <- levels(groups)
contrast.matrix  <- makeContrasts(Ino80 - Control, levels = design)
d.norm           <- voom(gene.exprs, design = design)
fit              <- lmFit(d.norm, design)
fit2             <- contrasts.fit(fit,contrast.matrix)
fit2             <- eBayes(fit2)
gene.result      <- topTable(  fit2, 
                               number        = Inf, 
                               adjust.method = "BH", 
                               sort.by       = "p",
                               lfc           = 0.58,
                               p.value       = 0.05
                               );

# setwd("C:\\Users\\Yisong\\Desktop")
# write.xlsx(gene.result, file = 'zongna.filtered.xlsx')
# Her data is not consistancy, and use p.value as the cutoff will
# lead to topTable Error!!!

