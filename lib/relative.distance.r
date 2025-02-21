require(faraway)
require(splinectomeR)
require(dplyr)

# creates a combined plot of relative L plots
# dms = list of distance matrices
# mains = vector of titles for plots
# all other are single values
multiplot.relative.L <- function(mains, dms, map0, ylab, xlab, x.var, ref_samples=NULL, ref.sample.order, outputfn, to.previous=F, override.cols.by=NULL)
{
    p <- list()
    for(i in 1:length(mains))
    {
        p[[i]] <- plot.relative.L(map0=map0, dm=dms[[i]], main=mains[i], ref.sample.order=ref.sample.order, ref_samples=ref_samples, xlab=xlab, ylab=ylab, x.var=x.var, to.previous=to.previous, override.cols.by=override.cols.by)
    }
    multiplot <- plot_grid(plotlist=p, ncol=length(p), nrow=1)
    save_plot(outputfn, multiplot, ncol = length(p), nrow = 1, base_aspect_ratio = 1.3)
}

# plot relative distances of longitudinal samples to either a set of ref samples OR a specific reference timepoint
# plot.by.day - plot the relative distance by the days since arrival
# x.var determines what to plot the x axis by (Diet.Day.Since.Arrival, Sample.Day.Since.Arrival, Sample.Order, Diet.Month)
# to.previous = instead of to 1 reference sample, just plot all samples relative to the previous one
# override.cols.by = override coloring by subject and instead color points by this column name in the map
# ref_samples should NOT be included in the map
plot.relative.L <- function(map0, otu0=NULL, main, ref.sample.order, ref_samples=NULL, xlab, ylab, 
                    x.var, to.previous=F, override.cols.by=NULL, dm=NULL, outputfn=NULL, similarity=FALSE, show.stats=TRUE)
{    
    ret <- prep.dm(map0, otu0, dm)
    ddm <- ret$ddm
    dm <- ret$dm
    map0 <- ret$map0
            print(colnames(map0))
    if(similarity)
        dm <- 1 - dm # UWUF only
        #dm <- 1/(1+dm)
print(map0$Sample.Order)
    r <- range(map0$Sample.Order)
print(r)
    timepoints <- r[1]:r[2]

    all.rel.distance <- NULL
    subjects <- sort(unique(map0$Subject.ID))

    cols <- alpha(colorRampPalette(brewer.pal(9, "Set1"))(length(subjects)),.3)    
   
    for(i in 1:length(subjects))
    {
        sub_map <- map0[map0$Subject.ID==subjects[i],]
        sub_map <- sub_map[order(sub_map$Sample.Order),] 
    
        query_samples <- rownames(sub_map)
        rel.distance <- NULL
                    
        if(to.previous==T)
        {
            for(j in 1:(nrow(sub_map)-1))
                rel.distance[j] <- as.numeric(dm[query_samples[j], query_samples[j+1]])
            names(rel.distance) <- query_samples[-1]
        }
        else
        {
            if(is.null(ref_samples))
            {    
                if(ref.sample.order == 1)
                    ref_samples_used <- rownames(sub_map)[sub_map$Sample.Order == min(sub_map$Sample.Order)]
                else
                    ref_samples_used <- rownames(sub_map)[sub_map$Sample.Order == max(sub_map$Sample.Order)]
    
                # if we dont pass in reference samples, then exclude calculated ref sample from query set
                query_samples <- query_samples[-which(query_samples==ref_samples_used)]
            }
            else
                ref_samples_used <- ref_samples

            for (j in 1:length(query_samples))
            {
                rel.distance[j] <- mean(as.numeric(dm[query_samples[j], ref_samples_used]))
            }
            names(rel.distance) <- query_samples
        }
    
        all.rel.distance <- c(all.rel.distance, rel.distance)        
    }

    ggdata <- data.frame(y=all.rel.distance, group=map0[names(all.rel.distance),"Subject.ID"], x=map0[names(all.rel.distance),x.var], row.names=names(all.rel.distance))

    if(is.null(override.cols.by))
    {    
        p <- ggplot(data=ggdata, aes(x=x, y=y, group=group, colour=group)) + geom_line() + scale_color_manual(values=cols) + 
            xlab(xlab) + ylab(ylab) + ggtitle(label=main) + theme(legend.position="none") + geom_point(size=4)
    }
    else  
    {        
        ggdata <- cbind(ggdata, points.cols = map0[names(all.rel.distance), override.cols.by])
        p <- ggplot(data=ggdata, aes(x=x, y=y, colour=points.cols)) + geom_line(colour="gray") + scale_color_manual(values=alpha(c("blue","gray","red"),.5)) + geom_point(size=4) +
            xlab(xlab) + ylab(ylab) + ggtitle(label=main) + theme(legend.title = element_blank()) # shows legend without title
    }
        
    # stat_smooth smooths on all data points
    p <- p + geom_smooth(aes(group = 1), size=2, se = FALSE, color=alpha("black",.7)) # loess line
    #p <- p + geom_smooth(aes(group = 1), method = "lm", size=2, se = FALSE) # straight line
    
    # use Robin's spline code to calculate p-value
    pvaltext <- paste("P = " , trendyspliner(data=ggdata, xvar="x", yvar="y", cases="group", perm=999, quiet=T)$pval)        
    if(show.stats)
        p <- ggdraw(p) + draw_figure_label(pvaltext, size=8, position="bottom.right")
    else
        print(pvaltext)
   
   if(!is.null(outputfn))
        save_plot(outputfn, p, ncol = 1, nrow = 1, base_aspect_ratio = 1.3)

    invisible(p)
}

# creates a combined plot of relative CS plots
# dms = list of distance matrices
# mains = vector of titles for plots
# all other are single values
multiplot.relative.CS <- function(mains, dms, map, ylab, xlab, x.var, ref_samples, outputfn)
{
    p <- list()
    for(i in 1:length(mains))
    {
        p[[i]] <- plot.relative.CS(map, dm=dms[[i]], main=mains[i], ref_samples=ref_samples, xlab=xlab, ylab=ylab, x.var=x.var)
    }
    multiplot <- plot_grid(plotlist=p, ncol=length(p), nrow=1)
    save_plot(outputfn, multiplot, ncol = length(p), nrow = 1, base_aspect_ratio = 1.3)
}


# plot relative distance of cross sectional samples to a set of reference samples
# map0 should contain query samples only
plot.relative.CS <- function(map0, otu0, dm=NULL, main, ref_samples, xlab, ylab, x.var, outputfn=NULL, show.stats=TRUE, similarity=FALSE)
{
    ret <- prep.dm(map0=map0, otu0=otu0, dm=dm, add.samples.dm=ref_samples)
    dm <- ret$dm
    map0 <- ret$map0

    query_samples <- rownames(map0)

    if(similarity)
        dm <- 1/(1+dm)

    rel.distance <- get.relative.distance(query_samples, ref_samples, dm)
        
    cortest <- cor.test(rel.distance, map0[,x.var], method="spear", exact=F)

    cor.label <- substitute(paste(rho, " = ", estimate, ", P = ", pvalue),
                    list(estimate = signif(cortest$estimate, 2), pvalue = signif(cortest$p.value, 2)))


    ggdata <- data.frame(y=rel.distance, x=map0[names(rel.distance),x.var], row.names=names(rel.distance))

    p <- ggplot(data=ggdata, aes(x=x, y=y)) + geom_point(size=2, colour=alpha("black",.3)) +
            xlab(xlab) + ylab(ylab) + ggtitle(label=main) + theme(legend.position="none", axis.title=element_text(size=15))
    # stat_smooth smooths on all data points
    p <- p + stat_smooth(aes(group = 1), method = "lm", se = FALSE, size=1, color="black")

    # add stats to bottom right 
    if(show.stats)
        p <- ggdraw(p) + draw_label(cor.label, size=9, x=1, y=0, hjust=1, vjust=0) # this is the perfect location!

    if(!is.null(outputfn))
        save_plot(outputfn, p, ncol = 1, nrow = 1, base_aspect_ratio = 1.3)

    invisible(p)
}

# for plotting only
plot.relative.CS.facet <- function(map0, otu0, dm=NULL, ref_samples1, ref_samples2, xlab, x.var, similarity=FALSE)
{
    ret <- prep.dm(map0=map0, otu0=otu0, dm=dm, add.samples.dm=ref_samples1)
    dm1 <- ret$dm
    ret <- prep.dm(map0=map0, otu0=otu0, dm=dm, add.samples.dm=ref_samples2)
    dm2 <- ret$dm

    query_samples <- rownames(map0)

    if(similarity)
    { 
        dm1 <- 1/(1+dm1)
        dm2 <- 1/(1+dm2)
    }
    rel.distance1 <- get.relative.distance(query_samples, ref_samples1, dm1)
    rel.distance2 <- get.relative.distance(query_samples, ref_samples2, dm2)


    ggdata <- rbind(data.frame(y=rel.distance1, x=map0[names(rel.distance1),x.var], facet="Similarity to Thai"),
                    data.frame(y=rel.distance2, x=map0[names(rel.distance2),x.var], facet="Similarity to US"))

    p <- ggplot(data=ggdata, aes(x=x, y=y)) + geom_point(size=2, colour=alpha("black",.3)) +
            xlab(xlab) +ylab("") + theme(legend.position="none", axis.title=element_text(size=17)) +
            facet_grid(. ~ facet) + theme(strip.background = element_blank(), strip.text.x = element_text(size = 20, face="bold"))
            

    p <- p + stat_smooth(aes(group = 1), method = "lm", se = FALSE, size=1, color="black")

    return(p)
}
















