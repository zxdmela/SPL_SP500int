# clear history
rm(list = ls(all = TRUE))
graphics.off()

# set working directory
#setwd("...")

# Install packages if not installed
libraries = c("tseries", "ccgarch")
lapply(libraries, function(x) if (!(x %in% installed.packages())) {
  install.packages(x)
})

# Load packages
lapply(libraries, library, quietly = TRUE, character.only = TRUE)

# import data
stock = as.data.frame(read.csv("data_stock.csv", header = T, sep = ","))

# get daily return of each stock
price = stock[, 2:11]
value = matrix(stock[, 12], nrow = T)
T = nrow(price)
n = ncol(price)

return = log(price[2, ]/price[1, ])
for (j in 2:(T - 1)) {
    return[j, ] = log(price[j + 1, ]/price[j, ])
}

# define portfolio: a value weighted portfolio containing one unit of each stock
W = matrix(unlist(price[1, ]/value[1, ]), nrow = n, ncol = 1)
alpha95 = 1.65
alpha99 = 2.33

# use AR(1) model to get the residual of stock use time interval t=200, there are
# 247-200+1=48 intervals(T-t)

t = 200

VaR95 = matrix(0, nrow = T - t, ncol = 1)
VaR99 = matrix(0, nrow = T - t, ncol = 1)

for (j in 1:(T - t)) {
    
    ts = return[j:(j + t - 1), ]
    
    residual = matrix(0, nrow = t, ncol = n)
    
    for (i in 1:n) {
        residual[, i] = matrix(residuals(arma(ts[, i], order = c(1, 0))))
    }
    
    residual = residual[-1, ]
    
    coef = matrix(0, nrow = n, ncol = 3)
    
    # initial GARCH model estimation
    for (i in 1:10) {
        coef[i, ] = matrix(coef(garch(residual[, i], order = c(1, 1), series = NULL)))
        
    }
    
    # DCC-GARCH model estimation
    a = coef[, 1]
    A = diag(coef[, 2])
    B = diag(coef[, 3])
    dcc.para = c(0.01, 0.97)
    results = dcc.estimation(inia = a, iniA = A, iniB = B, ini.dcc = dcc.para, dvar = residual, 
        model = "diagonal")
    h = results$h
    dcc = results$DCC
    v = sqrt(diag(h[t - 1, ]))
    R = matrix(data = dcc[1, ], nrow = n, ncol = n)
    H = v %*% R %*% v
    
    VaR95[j, ] = sqrt(t(W) %*% H %*% W) * alpha95 * value[j]
    VaR99[j, ] = sqrt(t(W) %*% H %*% W) * alpha99 * value[j]
    
}

VaR = cbind(VaR95, VaR99)

# profit&loss
value = matrix(value, nrow = T)
PL = value[(t + 1):T, ] - value[t:(T - 1), ]

bt = cbind(PL, -VaR)
colnames(bt) = c("PL", "95%VaR", "99%VaR")
matplot(c(1:(T - t)), bt[, 1:3], type = "l", xlab = "time", ylab = "P&L", xaxt = "n")
legend("topright", colnames(bt)[-1], lwd = 1, col = 2:3, cex = 0.75)
title("Portfolio P&L and estimated VaR")
axis(1, at = c(1:(T - t)), las = 0)

